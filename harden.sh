#!/usr/bin/env bash
set -Eeuo pipefail

ADMIN_USER="${ADMIN_USER:-devops}"
SSH_PORT="${SSH_PORT:-22}"
DRY_RUN=false
ALLOW_HTTP=false
ALLOW_HTTPS=false
LOG_FILE="/var/log/linux-server-hardening.log"
BACKUP_ROOT="/var/backups/linux-server-hardening"

usage() {
cat <<'EOF'
Usage: sudo ./harden.sh [options]
  --admin-user USER   Admin user (default: devops)
  --ssh-port PORT     SSH port (default: 22)
  --allow-http        Allow TCP/80 in UFW
  --allow-https       Allow TCP/443 in UFW
  --dry-run           Show actions without changing the system
  -h, --help          Show help

PasswordAuthentication is disabled only when the admin user already has
a non-empty ~/.ssh/authorized_keys file.
EOF
}

log(){ echo "$(date '+%F %T') [hardening] $*" | tee -a "${LOG_FILE}" 2>/dev/null || true; }
die(){ log "ERROR: $*"; exit 1; }
run(){ if "$DRY_RUN"; then printf '[DRY-RUN] '; printf '%q ' "$@"; echo; else "$@"; fi; }

while (($#)); do
  case "$1" in
    --admin-user) ADMIN_USER="${2:?Missing user}"; shift 2;;
    --ssh-port) SSH_PORT="${2:?Missing port}"; shift 2;;
    --allow-http) ALLOW_HTTP=true; shift;;
    --allow-https) ALLOW_HTTPS=true; shift;;
    --dry-run) DRY_RUN=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2;;
  esac
done

[[ $EUID -eq 0 ]] || die "Run with sudo/root."
source /etc/os-release
[[ "${ID:-}" == ubuntu ]] || die "Ubuntu is required."
case "${VERSION_ID:-}" in 22.04|24.04) ;; *) die "Supported Ubuntu: 22.04/24.04";; esac
[[ "$SSH_PORT" =~ ^[0-9]+$ ]] && ((SSH_PORT>=1 && SSH_PORT<=65535)) || die "Invalid SSH port."

STAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP_DIR="${BACKUP_ROOT}/${STAMP}"
run mkdir -p "$BACKUP_DIR"

backup_file(){
  local f="$1"
  [[ -e "$f" ]] || return 0
  local dst="${BACKUP_DIR}/${f#/}"
  run mkdir -p "$(dirname "$dst")"
  run cp -a "$f" "$dst"
}

log "Starting hardening on Ubuntu ${VERSION_ID}; dry-run=${DRY_RUN}"

run apt-get update
run env DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
run env DEBIAN_FRONTEND=noninteractive apt-get install -y sudo openssh-server ufw fail2ban unattended-upgrades

if ! id "$ADMIN_USER" >/dev/null 2>&1; then
  run useradd --create-home --shell /bin/bash "$ADMIN_USER"
  "$DRY_RUN" || passwd -l "$ADMIN_USER"
fi
id -nG "$ADMIN_USER" 2>/dev/null | tr ' ' '\n' | grep -qx sudo || run usermod -aG sudo "$ADMIN_USER"

HOME_DIR="$(getent passwd "$ADMIN_USER" | cut -d: -f6)"
run install -d -m 700 -o "$ADMIN_USER" -g "$ADMIN_USER" "$HOME_DIR/.ssh"
if [[ -e "$HOME_DIR/.ssh/authorized_keys" ]]; then
  run chown "$ADMIN_USER:$ADMIN_USER" "$HOME_DIR/.ssh/authorized_keys"
  run chmod 600 "$HOME_DIR/.ssh/authorized_keys"
fi

backup_file /etc/ssh/sshd_config
DROPIN=/etc/ssh/sshd_config.d/99-server-hardening.conf
backup_file "$DROPIN"

PASSWORD_AUTH=yes
if [[ -s "$HOME_DIR/.ssh/authorized_keys" ]]; then
  PASSWORD_AUTH=no
else
  log "WARNING: no authorized key for ${ADMIN_USER}; password SSH remains enabled to avoid lockout."
fi

TMP="$(mktemp)"
cat >"$TMP" <<EOF
# Managed by linux-server-hardening
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication ${PASSWORD_AUTH}
KbdInteractiveAuthentication no
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
LoginGraceTime 30
EOF

if "$DRY_RUN"; then
  echo "[DRY-RUN] would install ${DROPIN}:"
  cat "$TMP"
else
  install -m 644 "$TMP" "$DROPIN"
  sshd -t || die "sshd configuration validation failed."
  systemctl reload ssh
fi
rm -f "$TMP"

run ufw default deny incoming
run ufw default allow outgoing
run ufw allow "${SSH_PORT}/tcp"
"$ALLOW_HTTP" && run ufw allow 80/tcp
"$ALLOW_HTTPS" && run ufw allow 443/tcp
if "$DRY_RUN"; then echo "[DRY-RUN] ufw --force enable"; else ufw --force enable; fi

JAIL=/etc/fail2ban/jail.d/sshd.local
backup_file "$JAIL"
TMP="$(mktemp)"
cat >"$TMP" <<EOF
[sshd]
enabled = true
port = ${SSH_PORT}
backend = systemd
maxretry = 5
findtime = 10m
bantime = 10m
EOF
if "$DRY_RUN"; then
  echo "[DRY-RUN] would install ${JAIL}:"
  cat "$TMP"
else
  install -m 644 "$TMP" "$JAIL"
  systemctl enable --now fail2ban
  systemctl restart fail2ban
fi
rm -f "$TMP"

AUTO=/etc/apt/apt.conf.d/20auto-upgrades
backup_file "$AUTO"
TMP="$(mktemp)"
cat >"$TMP" <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
if "$DRY_RUN"; then
  echo "[DRY-RUN] would install ${AUTO}:"
  cat "$TMP"
else
  install -m 644 "$TMP" "$AUTO"
  systemctl enable --now unattended-upgrades.service || true
fi
rm -f "$TMP"

if ! "$DRY_RUN"; then
  sshd -t
  systemctl is-active --quiet ssh || die "SSH is not active."
  systemctl is-active --quiet fail2ban || die "Fail2ban is not active."
  ufw status | grep -q 'Status: active' || die "UFW is not active."
  log "Effective SSH settings:"
  sshd -T | grep -E '^(permitrootlogin|pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|maxauthtries|x11forwarding) ' || true
fi

log "Hardening completed successfully."

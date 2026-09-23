#!/usr/bin/env bash
set -Eeuo pipefail

fail(){ echo "[FAIL] $*"; exit 1; }
ok(){ echo "[ OK ] $*"; }

[[ $EUID -eq 0 ]] || fail "Run with sudo/root"

sshd -t || fail "Invalid sshd configuration"
ok "sshd configuration syntax"

SSH_EFFECTIVE="$(sshd -T)"
grep -q '^permitrootlogin no$' <<<"$SSH_EFFECTIVE" || fail "PermitRootLogin is not disabled"
grep -q '^pubkeyauthentication yes$' <<<"$SSH_EFFECTIVE" || fail "Public key authentication is not enabled"
grep -q '^passwordauthentication no$' <<<"$SSH_EFFECTIVE" || fail "PasswordAuthentication is not disabled"
grep -q '^maxauthtries 3$' <<<"$SSH_EFFECTIVE" || fail "MaxAuthTries is not 3"
ok "effective SSH hardening"

ufw status | grep -q 'Status: active' || fail "UFW is not active"
ok "UFW active"

systemctl is-active --quiet ssh || fail "SSH service inactive"
systemctl is-active --quiet fail2ban || fail "Fail2ban inactive"
systemctl is-active --quiet unattended-upgrades || fail "unattended-upgrades inactive"
ok "required services active"

fail2ban-client status sshd >/dev/null || fail "Fail2ban sshd jail unavailable"
ok "Fail2ban sshd jail"

[[ -f /etc/apt/apt.conf.d/20auto-upgrades ]] || fail "automatic updates config missing"
ok "automatic updates config"

echo "All smoke tests passed."

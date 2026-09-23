# Linux Server Hardening

A Bash-based educational project that applies a repeatable baseline hardening configuration to Ubuntu Server 22.04/24.04.

> This project demonstrates baseline server hardening and verification. It does **not** claim to make a server fully secure or production-ready.

## Features

- Ubuntu/root validation
- Package updates and security tooling
- Administrative user and sudo verification
- SSH directory/file permission enforcement
- SSH hardening with `sshd -t` validation
- Lockout protection: password authentication is disabled only when an authorized key exists
- UFW default-deny incoming policy
- Optional HTTP/HTTPS firewall rules
- Fail2ban SSH jail
- Automatic security updates
- Backups of configuration files before changes
- Execution logging
- `--help` and `--dry-run`
- Repeatable/idempotent behavior for the managed configuration

## Tested environment

- Ubuntu Server 24.04 ARM64
- OpenSSH Server
- UFW
- Fail2ban
- Nginx used to verify that HTTP remains available when `--allow-http` is selected

## Usage

```bash
chmod +x harden.sh
./harden.sh --help
bash -n harden.sh
sudo ./harden.sh --dry-run --admin-user devops --allow-http
sudo ./harden.sh --admin-user devops --allow-http
```

Keep an existing SSH session open during the first real run. After completion, open a second SSH connection before closing the original session.

## Verification

```bash
sudo sshd -t
sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication|pubkeyauthentication|maxauthtries|x11forwarding'
sudo ufw status verbose
systemctl is-active ssh fail2ban unattended-upgrades
sudo fail2ban-client status sshd
sudo find /var/backups/linux-server-hardening -type f | sort
sudo tail -30 /var/log/linux-server-hardening.log
```

The lab was tested with two consecutive real runs. The second run completed successfully, existing UFW rules were reused, SSH configuration remained valid, the required services remained active, and the Nginx endpoint still returned HTTP 200.

## Repository structure

```text
linux-server-hardening/
├── README.md
├── harden.sh
├── config/
│   ├── sshd_config.example
│   └── jail.local.example
├── tests/
│   └── smoke-test.sh
├── docs/
│   ├── threat-model.md
│   ├── rollback.md
│   └── verification.md
├── .gitignore
└── LICENSE
```

## Safety and limitations

This is a portfolio/learning project. Security requirements vary by environment. The script does not configure centralized identity, SIEM, EDR, disk encryption, application-specific controls, compliance frameworks, network segmentation, secret management, or a complete production security baseline. Review every change before using it on a real server.

See `docs/threat-model.md`, `docs/rollback.md`, and `docs/verification.md`.

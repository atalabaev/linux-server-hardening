# Verification

## Static script checks

```bash
bash -n harden.sh
./harden.sh --help
```

## Dry run

```bash
sudo ./harden.sh --dry-run --admin-user devops --allow-http
```

Review the planned SSH, firewall, Fail2ban, update, backup, and permission changes before applying them.

## Real run

```bash
sudo ./harden.sh --admin-user devops --allow-http
```

Keep the original SSH session open and verify a second SSH login succeeds.

## Security state

```bash
sudo sshd -t
sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication|pubkeyauthentication|maxauthtries|x11forwarding'
sudo ufw status verbose
systemctl is-active ssh fail2ban unattended-upgrades
sudo fail2ban-client status sshd
```

Expected SSH baseline:

```text
maxauthtries 3
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
x11forwarding no
```

## Backups and logging

```bash
sudo find /var/backups/linux-server-hardening -type f | sort
sudo tail -30 /var/log/linux-server-hardening.log
```

## Idempotency check

Run the hardening command a second time:

```bash
sudo ./harden.sh --admin-user devops --allow-http
```

The second run should complete without breaking SSH or services and should not duplicate existing firewall rules.

## Automated smoke test

```bash
sudo ./tests/smoke-test.sh
```

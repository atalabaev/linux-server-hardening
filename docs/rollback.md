# Rollback

The script creates timestamped backups below:

```text
/var/backups/linux-server-hardening/YYYYMMDD-HHMMSS/
```

## SSH rollback

Keep the current SSH session open.

```bash
sudo find /var/backups/linux-server-hardening -type f | sort
sudo rm -f /etc/ssh/sshd_config.d/99-server-hardening.conf
```

If a previous managed drop-in exists in the selected backup, restore it to its original path. Validate before reload:

```bash
sudo sshd -t
sudo systemctl reload ssh
```

Never close the working SSH session until a second connection succeeds.

## UFW rollback

Inspect rules first:

```bash
sudo ufw status numbered
```

For an emergency lab rollback:

```bash
sudo ufw disable
```

Then correct the rules before enabling it again.

## Fail2ban rollback

```bash
sudo rm -f /etc/fail2ban/jail.d/sshd.local
sudo systemctl restart fail2ban
```

## Automatic updates rollback

Restore the backed-up `/etc/apt/apt.conf.d/20auto-upgrades` file from the appropriate timestamped backup.

## Verification after rollback

```bash
sudo sshd -t
systemctl is-active ssh
sudo ufw status verbose
systemctl status fail2ban --no-pager
```

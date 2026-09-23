# Threat Model

## Scope

The project protects a small Ubuntu Server against common baseline risks while keeping the host remotely manageable.

## Threats addressed

- Direct remote root login
- Password-based SSH attacks after key access is confirmed
- Excessive SSH authentication attempts
- Unnecessary inbound network exposure
- Repeated SSH brute-force attempts
- Missing routine security updates
- Unsafe SSH file permissions
- Configuration changes without a local rollback copy

## Controls

SSH is restricted through a drop-in configuration, validated with `sshd -t`, and reloaded only after validation. UFW uses default deny for incoming traffic and explicitly allows required ports. Fail2ban monitors SSH authentication failures. Unattended upgrades provide automatic security update handling. Original configuration files are copied into timestamped backup directories before managed changes.

## Out of scope

This lab does not provide a complete production security architecture. It does not cover centralized IAM, MFA, EDR, SIEM, full audit policy, disk encryption, application hardening, container security, network segmentation, vulnerability management, compliance certification, or secret management.

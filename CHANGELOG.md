# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), with architectural changes recorded in Architectural Decision Record (ADR) format.

## [2026-09-06]

### ADR: Dedicated Read-Only Service Account (`agy-auditor`) for Agent Telemetry

#### Context
Automated diagnostic workflows and pair-programming agents require inspection access to host network interfaces (`wg0`, `vmbr0`), firewall rules (`iptables`, `nftables`), virtualization status (`pct`, `qm`), and system service health on `rath15nas` (`192.168.68.169`). Granting unrestricted administrative access or sharing the interactive `bjm` account creates security risks and violates the Principle of Least Privilege (PoLP).

#### Action
1. Provisioned dedicated system user `agy-auditor` on `rath15nas` with disabled password authentication (`passwd -l`).
2. Configured public-key-only SSH access using dedicated key `~/.ssh/id_ed25519_agy` into `/home/agy-auditor/.ssh/authorized_keys` with `700`/`600` permissions owned by `agy-auditor:agy-auditor`.
3. Added `/etc/sudoers.d/agy-readonly` allowing passwordless sudo strictly for read-only inspection commands:
   * `/usr/bin/wg show*`
   * `/usr/sbin/iptables -S*`
   * `/usr/sbin/iptables -L*`
   * `/usr/sbin/nft list*`
   * `/usr/sbin/pct list`
   * `/usr/sbin/qm list`
   * `/usr/bin/systemctl status *`
4. Added SSH client alias `rath15nas-agent` in `~/.ssh/config` pointing to `192.168.68.169` as user `agy-auditor` with `IdentityFile ~/.ssh/id_ed25519_agy`.

#### Consequences
* **Positive:** Diagnostic tools and agents can inspect WireGuard tunnel state, packet filters, container states, and service status non-interactively without requiring administrative passwords.
* **Positive:** Mutating commands (e.g., stopping services, modifying routing/firewall rules, editing configuration files) are explicitly denied by sudo.
* **Operational:** All future agent-driven telemetry and diagnostic queries target `rath15nas-agent`. Administrative operations remain restricted to `bjm` via explicit operator approval.

# ADR-0008: Revocation of Root SSH on LXC 920 and Deployment of Least-Privilege Read-Only Auditor (`services-agent`)

* **Status:** Accepted
* **Date:** 2026-09-07
* **Component:** Security & Identity
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Unintended Root Privilege Surface:** During initial container provisioning (`01-create-lxc.sh`), the operator's primary workstation SSH key was injected into `/root/.ssh/authorized_keys` inside LXC 920 (`services`, `192.168.68.175`). This inadvertently allowed direct root SSH mutation by automation agents from the operator's workstation, violating the intended boundary where all mutations must be executed strictly by the human operator via Proxmox (`pct exec`).
2. **Telemetry & Diagnostic Requirement:** The agent requires read-only inspection access to Docker containers (`docker ps`, `docker logs`, `docker inspect`), network sockets (`ss`), and service unit health (`systemctl status`) to diagnose issues without requiring administrative passwords or interactive operator intervention.

## Action
1. **Root Key Revocation (`14-setup-readonly-auditor.sh`):**
   * Purged and truncated `/root/.ssh/authorized_keys` on LXC 920.
   * Direct root SSH access to `root@192.168.68.175` is permanently severed (`Permission denied`).
2. **Dedicated Read-Only Service Account (`agy-auditor`):**
   * Provisioned dedicated system user `agy-auditor` on LXC 920 with disabled password authentication (`passwd -l`).
   * Authorized public-key-only SSH access using dedicated key `~/.ssh/id_ed25519_agy`.
   * Installed strict sudoers whitelist `/etc/sudoers.d/agy-readonly` restricted to:
     * `/usr/bin/docker ps*`
     * `/usr/bin/docker inspect*`
     * `/usr/bin/docker logs*`
     * `/usr/bin/systemctl status*`
     * `/usr/bin/ss*`
     * `/usr/bin/cat /opt/stacks/*`
   * Mutating commands (`docker run`, `docker exec`, `docker stop`, filesystem writes) are strictly denied by sudo.
3. **Client Configuration:**
   * Configured SSH client alias `services-agent` in `~/.ssh/config` pointing to `192.168.68.175` as `agy-auditor` with key `~/.ssh/id_ed25519_agy`.

## Consequences
* **Positive:** Complete least-privilege alignment across both hypervisor (`rath15nas-agent`) and container (`services-agent`).
* **Security:** Agent has zero root or mutating capabilities on any host. All container mutations require operator-reviewed scripts executed via `sudo pct exec 920`.
* **Operational:** Diagnostic telemetry, container states, and logs remain seamlessly inspectable non-interactively.

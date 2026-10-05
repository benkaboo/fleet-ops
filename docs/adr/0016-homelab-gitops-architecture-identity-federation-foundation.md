# ADR-0016: Homelab GitOps Architecture & Identity Federation Foundation

* **Status:** Accepted
* **Date:** 2026-10-03
* **Component:** Networking / VPN
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Application Lifecycle Decoupling & Incus Readiness:** Container services hosted in LXC 920 were previously managed and deployed through imperative bash scripts (`01-create-lxc.sh` through `21-fix-homepage-hosts.sh`). To prepare for a seamless future migration to Incus (LXD community fork) and eliminate hypervisor lock-in, application definitions, reverse proxy rules, and configurations needed to be decoupled from Proxmox commands (`pct exec`, `pct push`) into a single declarative source of truth.
2. **Cross-Site Authentication Federation:** The operator and his brother sought to federate authentication rules between their homelabs (linking Dixon and Maslen networks across WireGuard). Both operators required the capability to collaboratively manage accounts, share access control rules, and establish mutual service failover.
3. **Resilience & Governance:** Direct synchronous authentication over a WAN WireGuard link risks locking out local users during ISP downtime. A multi-stage architecture utilizing GitOps for configuration synchronization, local LLDAP as a decoupled user directory, and dual-domain Authelia rules was determined to provide high availability with zero WAN outage dependency.

## Action
1. **GitHub Private GitOps Repository (`homelab-stacks`):**
   * Initialized private GitOps repository `git@github.com:benkaboo/homelab-stacks.git` on GitHub.
   * Staged declarative codebase locally at `C:\Users\benma\coding\agy_project\Projects\homelab-stacks`.
   * Enforced strict `.gitignore` boundaries excluding stateful runtime databases (`*.sqlite3`, `*.db`), secret files (`.env`), TLS keys/certificates (`*.key`, `*.pem`), and application data directories.
2. **Declarative Service Extraction & Sanitization:**
   * Harvested and formatted all 11 active container stacks from LXC 920 (`caddy`, `dockge`, `authelia`, `jellyfin`, `audiobookshelf`, `calibre-web`, `filebrowser`, `adguard`, `homepage`, `uptime-kuma`, `rest-server`).
   * Decoupled hardcoded secrets in Authelia's configuration into environment variable filters (`X_AUTHELIA_CONFIG_FILTERS=template`) and documented required parameters in `authelia.env.example`.
   * Staged the foundation for local LLDAP deployment (`lldap/compose.yaml` and `lldap.env.example`) on port 3890.
3. **Master Architecture Planning:**
   * Published comprehensive implementation blueprint detailing the 5-phase migration path from GitOps baseline to Incus portability.
4. **Initial Baseline Push:**
   * Committed and pushed clean declarative definitions to `origin main` on GitHub.

## Consequences
* **Positive:** All homelab application configurations and reverse proxy routes are now backed up offsite in an immutable, auditable Git repository.
* **Positive:** Collaborative foundation established for brother to review and contribute to shared ACL rules via Pull Requests.
* **Positive:** Provides the exact prerequisite structure needed to migrate container stacks to Incus in the future with a single `git clone`.
* **Security:** Guaranteed zero-secret leakage into version control through template abstraction and strict git ignore rules.
* **Operational:** Stacks will transition to Git-driven deployment via deploy keys rather than imperative host scripts.

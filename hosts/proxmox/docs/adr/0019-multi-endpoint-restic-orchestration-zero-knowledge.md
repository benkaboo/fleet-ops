# ADR-0019: Multi-Endpoint Restic Orchestration & Zero-Knowledge Server State Backups

* **Status:** Accepted
* **Date:** 2026-10-04
* **Component:** Media & Applications
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Multi-Endpoint Consolidation:** The operator maintained independent client-side Restic backup pipelines on the primary workstation (`LENOVO16_LP`) and living-room HTPC (`rath15-htpc`) terminating on `rest-server` with `--append-only` security flags. However, because clients had no administrative rights to prune or check repositories, backups lacked automated retention lifecycle enforcement, and operators had no unified pane of glass to inspect snapshot trees.
2. **Server Microservices & Database Protection:** Stateful application data (LLDAP user directory, Authelia sessions, Dockge compose records, FileBrowser metadata, Calibre-Web app state, Uptime Kuma monitors) and decrypted `.env` secrets on LXC 920 were excluded from the `homelab-stacks` GitOps repository by design. An automated, disaster-resilient backup pipeline was required to protect this state without committing secrets to Git.
3. **Operator Sovereignty & Zero-Knowledge Encryption:** Master repository encryption keys for backup repositories must adhere to zero-knowledge principles. The operator generated and stored the master key independently in Bitwarden, ensuring the assistant/agent never had visibility into the secret key.

## Action
1. **Multi-Endpoint Integration in Backrest:**
   * Linked existing client repositories (`workstation_lenovo_bm` at `/mnt/backups/workstation` and `rath15_htpc` at `/mnt/backups/htpc`) into Backrest using operator-provided Bitwarden vault keys.
   * Successfully indexed 28 historical snapshots for the workstation and 25 historical snapshots for the HTPC.
2. **Dedicated Server Repository Provisioning (`/mnt/backups/services`):**
   * Initialized a dedicated, AES-256 encrypted repository on `/mnt/backups/services` following tenant isolation principles (`--private-repos`).
   * Configured zero-knowledge key generation strictly within the operator's Bitwarden vault (`Homelab - Services Restic Repo Key`).
3. **Automated Server Backup Plan (`stacks_and_databases`):**
   * Created declarative plan in Backrest targeting `/userdata/stacks` (read-only mount of `/opt/stacks`).
   * Enforced cache and process log exclusions (`**/cache/**`, `**/processlogs/**`).
   * Scheduled automated daily snapshot execution at 03:00 AM (`0 3 * * *`).
   * Successfully executed baseline snapshot (`513a1f77`) capturing all compose definitions, secrets, and SQLite databases (deduplicated to 89 MB).
4. **Synchronized 7-4-12 Maintenance Lifecycle:**
   * Configured rolling retention across all three repositories (`workstation_lenovo_bm`, `rath15_htpc`, `services`): 7 daily, 4 weekly, and 12 monthly snapshots.
   * Synchronized automated weekly forget and prune jobs to run Sundays at 02:00 AM (`0 2 * * 0`).
   * Synchronized automated monthly integrity checks (`restic check`) to run on the 1st of every month at 03:00 AM (`0 3 1 * *`).

## Consequences
* **Positive:** Complete, automated disaster recovery established for all container services and databases without exposing secrets to Git.
* **Positive:** Operators possess a single, unified web interface to browse snapshots, perform file-level restores, and monitor storage across all three infrastructure tiers (Workstation, HTPC, Services).
* **Positive:** Automated garbage collection and pruning prevent infinite disk accumulation while guaranteeing one full year of point-in-time recovery milestones.
* **Security:** True zero-knowledge encryption maintained—master server backup key exists solely in the operator's Bitwarden vault.

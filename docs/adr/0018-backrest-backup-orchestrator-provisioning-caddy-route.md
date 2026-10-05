# ADR-0018: Backrest Backup Orchestrator Provisioning, Caddy Route & Admin Access Control

* **Status:** Accepted
* **Date:** 2026-10-04
* **Component:** Storage & Backup
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **State & Database Backup Governance:** Microservices deployed in LXC 920 generate stateful SQLite databases (`users.db`, `db.sqlite3`, `dockge.db`, `filebrowser.db`, `app.db`, `kuma.db`) and decoupled secret configurations (`.env`, `oidc.key`) that are intentionally excluded from GitOps version control.
2. **Visual Inspection & Snapshot Recovery:** While the underlying backup target (`rest-server` on `rath15nas` at port 8000) provides an append-only restic repository, operators require a web interface to inspect backup status, browse file-level snapshot trees, view run-to-run diffs, and perform self-service file restores without executing manual restic CLI commands.
3. **Least Privilege Ingress:** Because backup management interfaces possess snapshot browsing and administrative configuration capabilities across the entire stack, access to the backup dashboard must be strictly enforced via Authelia SSO and restricted exclusively to the `admins` role.

## Action
1. **Declarative Stack Definition (`backrest/compose.yaml`):**
   * Provisioned `ghcr.io/garethgeorge/backrest:latest` in private GitOps repository `benkaboo/homelab-stacks`.
   * Configured persistent container volumes for Backrest operational state: `/data`, `/config`, and `/cache`.
   * Mounted source paths read-only: `/opt/stacks` (mapped to `/userdata/stacks:ro`) and `/mnt/simba` (mapped to `/userdata/simba:ro`), ensuring zero risk of accidental mutation or file deletion during backup operations.
   * Bound repository target to `/mnt/backups`.
   * Joined container to `gateway_net` on internal port `9898` with timezone `Australia/Sydney`.
2. **Reverse Proxy Ingress & Authelia Access Control:**
   * Configured Caddy routes in `/opt/stacks/caddy/Caddyfile` for `backup.dixon.home` and `backup.192.168.68.175.nip.io` with automated internal PKI TLS certificates.
   * Enforced Authelia forward-auth middleware (`import authelia-auth`).
   * Updated Authelia's `configuration.yml` access control rules to require `one_factor` authentication restricted strictly to `subject: "group:admins"`.
3. **Dashboard Integration & Deployment Synchronization:**
   * Added Backrest service tile with `restic.png` icon to Homepage dashboard under Infrastructure & Administration.
   * Committed all declarative definitions to GitHub repository (`commit 5ef2f88`).
   * Pulled and deployed container on LXC 920 (`services`), reloading Caddy, restarting Authelia, and verifying HTTP 302 authentication protection.

## Consequences
* **Positive:** Operators now possess a centralized, intuitive web interface to orchestrate Restic snapshots, inspect backup contents, download historical files, and monitor repository deduplication health.
* **Positive:** Complete protection against unauthorized access by restricting the backup portal to authenticated users in the `admins` LDAP group.
* **Positive:** Backed source trees are mounted strictly read-only, preventing backup tools from corrupting live application databases or media pools.
* **Operational:** Operators can now initialize Restic repositories and schedule backup tasks directly from `https://backup.dixon.home`.

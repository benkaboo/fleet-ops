# ADR-0017: LLDAP Identity Provider Provisioning, GitOps Deploy Key & Authelia Backend Cutover

* **Status:** Accepted
* **Date:** 2026-10-03
* **Component:** Media & Applications
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Directory Consolidation & Multi-User Access:** Authelia was previously operating with a static YAML file (`users_database.yml`) for user accounts. To allow the operator and his brother to manage accounts independently and provide role-based access to homelab services (Jellyfin, Books, Audiobookshelf, Files), a lightweight, standards-compliant LDAP directory was required.
2. **E-Reader & Non-Browser Clients:** Media and e-book services (Calibre-Web) provide OPDS catalogs for hardware e-readers (Kobo, Kindle) that cannot execute browser JavaScript or handle forward-auth web redirects. A native LDAP directory service enables direct HTTP Basic Auth verification for e-readers while preserving web SSO for desktop and mobile browsers.
3. **Automated Server Pull Authentication:** LXC 920 required read-only access to pull updates from the private `benkaboo/homelab-stacks` GitHub repository without storing personal GitHub account credentials or write tokens on the production container.

## Action
1. **Read-Only Deploy Key Provisioning:**
   * Generated dedicated Ed25519 deploy key (`~/.ssh/id_ed25519_deploy`) under user `bjm` on LXC 920 (`services`).
   * Configured `~/.ssh/config` for `Host github.com` mapping to the deploy key.
   * Registered the public key as a strictly read-only Deploy Key on GitHub repository `benkaboo/homelab-stacks`.
   * Initialized Git tracking in `/opt/stacks` directly linked to `origin/main` with `.gitignore` boundaries excluding stateful databases and secrets.
2. **LLDAP Container Deployment (`nitnelave/lldap:stable`):**
   * Configured `/opt/stacks/lldap/compose.yaml` with internal LDAP port `3890`, web UI port `17170`, base DN `dc=home,dc=arpa`, and persistent storage at `/opt/stacks/lldap/data`.
   * Stored cryptographically generated secrets in `/opt/stacks/lldap/.env` (`chmod 600`).
   * Configured Caddy reverse proxy route in `Caddyfile` for `https://ldap.dixon.home` and `https://ldap.192.168.68.175.nip.io` with automated internal PKI TLS.
   * Added LLDAP service tile to Homepage dashboard under Infrastructure & Administration.
3. **Directory Schema & User Initialization:**
   * Populated core role-based access control (RBAC) groups: `admins`, `family`, `lldap_admin`.
   * Provisioned operator account `bjm` (`Ben Maslen`, `ben.bmaslen@gmail.com`) assigned to `admins`, `family`, and `lldap_admin`.
4. **Authelia Backend Cutover:**
   * Updated `authelia/config/configuration.yml` to switch `authentication_backend` from `file` to `ldap` (`implementation: "lldap"`, `address: "ldap://lldap:3890"`, `base_dn: "dc=home,dc=arpa"`).
   * Upgraded attribute mappings to modern Authelia v4.39 schema (`attributes.group_name: "cn"`, `attributes.username: "uid"`, `attributes.mail: "mail"`, `attributes.display_name: "displayName"`).
   * Decoupled runtime secrets into `/opt/stacks/authelia/.env` using `HOMELAB_` prefix, bypassing Authelia's template security filter.
   * Validated configuration with `authelia config validate` (passed with 0 errors and 0 warnings).
   * Recreated Authelia container and validated `/api/health` returns `status: OK`.

## Consequences
* **Positive:** Centralized LDAP identity directory established for all current and future homelab services.
* **Positive:** Authelia web portal, Caddy forward-auth, and Jellyfin OIDC authenticate seamlessly against LLDAP credentials.
* **Positive:** Hardware e-readers (Kobo, Kindle) can connect directly to Calibre-Web's OPDS catalog using LDAP credentials without browser SSO redirection failures.
* **Positive:** Autonomous, credential-free GitOps deployments enabled on LXC 920 via read-only deploy key.
* **Operational:** Production `/opt/stacks` now synchronized via `git pull` from GitHub repository `homelab-stacks`.

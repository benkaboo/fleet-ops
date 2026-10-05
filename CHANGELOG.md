# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), with architectural changes recorded in Architectural Decision Record (ADR) format.

## [2026-10-05]

### ADR: NVIDIA GeForce GTX 1080 Ti Production Driver Deployment & Proxmox Kernel 6.17 DRM Stabilization

#### Context
1. **Hardware Acceleration Requirement:** Containerized services on LXC 920 (specifically Immich Machine Learning for facial recognition/CLIP embeddings and Jellyfin for NVENC transcoding) required unlocking the host's dedicated NVIDIA GeForce GTX 1080 Ti (11 GB VRAM, GP102 architecture).
2. **Kernel 6.17 DRM API Incompatibility:** Upstream Debian 13 (Trixie) default packages (`nvidia-kernel-dkms` 550.163.01) failed DKMS compilation against the running Linux `6.17.2-1-pve` kernel due to breaking DRM function signature changes (`drm_helper_mode_fill_fb_struct` 4-argument signature).
3. **Open-Kernel Module Incompatibility on Pascal:** When switching to the official NVIDIA CUDA repository, unpinned dependency resolution defaulted to branch 615 open-source kernel modules (`nvidia-kernel-open-dkms`). However, NVIDIA open-kernel modules strictly require an on-die GPU System Processor (GSP) only available on Turing and newer architectures. Attempting to probe this incompatible module caused kernel hangs during boot, resulting in `udevadm settle` and `ifupdown2-pre.service` timing out and preventing `networking.service` from creating `vmbr0`.

#### Action
1. **Network Recovery & Root Cause Isolation:**
   * Diagnosed boot failure at console; bypassed systemd dependency deadlock using direct kernel netlink configuration (`ip link add name vmbr0 type bridge`, attaching physical port `nic0`, and applying static IP `192.168.68.169/24`).
   * Cleaned hanging udev trigger rules and unmasked `ifupdown2-pre.service`.
2. **Branch Standardization & Native Kernel 6.17 DRM Compatibility:**
   * Identified NVIDIA 580 (`580.178.04-1`) as the final official production driver branch supporting Pascal (`GP102` / `10de:1b06`) that provides native support for Linux 6.17 DRM APIs.
   * Successfully validated DKMS compilation against `6.17.2-1-pve` kernel headers in isolated staging (`/tmp/dkms580`).
3. **Repository Pinning & Driver Installation (`scripts/gpu/01-host-nvidia-setup.sh`):**
   * Completely purged incompatible 615 open packages.
   * Installed `nvidia-driver-pinning-580` (`/etc/apt/preferences.d/nvidia-driver-pin`) with priority 1000 to permanently lock APT solvers to the 580 branch and prevent future regressions to incompatible open modules.
   * Installed `cuda-drivers-580` (proprietary DKMS driver, CUDA 13.0 toolchain, `nvidia-smi`, `nvidia-persistenced`).
   * Blacklisted `nouveau` in `/etc/modprobe.d/blacklist-nouveau.conf`.
   * Persisted module loading (`nvidia`, `nvidia-uvm`, `nvidia-modeset` in `/etc/modules-load.d/nvidia.conf`) and device node permissions in `/etc/udev/rules.d/70-nvidia.rules`.
   * Updated initramfs (`update-initramfs -u -k all`).
4. **Verification & Post-Boot Health Check:**
   * Performed clean host reboot.
   * Confirmed zero failed systemd units (`systemctl --failed` reported 0).
   * Confirmed `vmbr0` initialized automatically on boot with `192.168.68.169/24`.
   * Verified `nvidia-smi` reports driver `580.178.04`, CUDA `13.0`, and full access to GeForce GTX 1080 Ti (11,264 MiB VRAM).
   * Verified LXC 920 (`192.168.68.175`) booted automatically and remains accessible.

#### Consequences
* **Positive:** GeForce GTX 1080 Ti is fully initialized, stable, and ready for LXC cgroup device passthrough.
* **Positive:** Clean, reliable boot sequence restored; `ifupdown2-pre.service` and `networking.service` initialize in milliseconds with zero timeouts.
* **Positive:** APT repository pinned against future regressions; host system upgrades will not pull broken open-kernel drivers.
* **Operational:** Staged setup scripts (`01-host-nvidia-setup.sh`) maintained in repository for auditability and future hypervisor rebuilds.

---

### ADR: Authelia OIDC Single Sign-On Federation for Immich & In-Cluster TLS Trust

#### Context
1. **Single Sign-On (SSO) Unification:** Following the deployment of the Immich photo management stack, the operator required federated authentication against the centralized homelab identity system (Authelia backed by LLDAP directory `dc=home,dc=arpa`). This enables family members to authenticate seamlessly across both desktop browsers and native mobile apps without maintaining separate local passwords.
2. **Backchannel Token Verification & Internal PKI Trust:** Immich is a Node.js/NestJS service running inside a container. Node.js relies on an internal, hardcoded Mozilla root CA bundle and does not consult host system trust stores by default. Because Caddy terminates HTTPS using internal PKI (`tls internal`), backchannel OIDC discovery and authorization code/token exchanges between `immich-server` and `auth.dixon.home` failed with TLS local issuer errors and NXDOMAIN lookups.
3. **Decoupled Secret Discipline & GitOps:** In accordance with the GitOps decoupled secret pattern, client registration must be committed to the declarative repository (`benkaboo/homelab-stacks`) using template expansion (`HOMELAB_IMMICH_CLIENT_SECRET`), while the one-way PBKDF2 hash is hydrated directly into `/opt/stacks/authelia/.env` on LXC 920.

#### Action
1. **Authelia Client Registration (`benkaboo/homelab-stacks`):**
   * Configured client `immich` in `authelia/config/configuration.yml` with `authorization_policy: one_factor`, `client_secret_post`, and redirect URIs supporting desktop and mobile deep links (`app.immich:///oauth-callback`, `https://photos.dixon.home/api/oauth/mobile-redirect`, `https://photos.dixon.home/auth/login`, and `.nip.io` variants).
   * Updated `authelia/authelia.env.example` template with `HOMELAB_IMMICH_CLIENT_SECRET`.
   * Committed and pushed to GitHub (`0058fdb`).
2. **Runtime Secret Hydration on LXC 920:**
   * Pulled updates on LXC 920 (`/opt/stacks`).
   * Backed up `/opt/stacks/authelia/.env` to `.env.bak`.
   * Generated 32-character random client secret and calculated the PBKDF2 digest using Authelia's crypto engine (`docker exec authelia authelia crypto hash generate pbkdf2`).
   * Appended `HOMELAB_IMMICH_CLIENT_SECRET` to `/opt/stacks/authelia/.env` and recreated Authelia container (`docker compose up -d --force-recreate authelia`).
3. **In-Cluster TLS Trust & Host Resolution (`immich/compose.yaml`):**
   * Updated `immich/compose.yaml` with `extra_hosts` mapping `auth.dixon.home:192.168.68.175`.
   * Mounted host CA bundle `/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro`.
   * Injected environment variable `NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt` so Node.js trusts Caddy's internal root CA.
   * Committed to GitHub (`4cdf97c`), pulled on host, and recreated `immich_server`.
4. **Health & Endpoint Verification:**
   * Verified OIDC discovery endpoint `https://auth.dixon.home/.well-known/openid-configuration` returns HTTP 200 from both host and from inside `immich_server` with zero TLS verification or DNS errors.
   * Verified Caddy ingress HTTP 200 for both `auth` and `photos` services.
   * Synchronized updates to `ARCHITECTURE.md`.

#### Consequences
* **Positive:** Immich users can now authenticate via Authelia SSO across both desktop web and mobile clients.
* **Positive:** Backchannel OIDC token exchanges succeed natively over internal HTTPS without disabling TLS verification or relying on external DNS.
* **Positive:** Strict GitOps secret decoupling maintained: no plain or hashed secrets committed to version control; plaintext client secret secured in operator password vault (Bitwarden).
* **Operational:** Auto-registration enabled in Immich OAuth allows family accounts in LLDAP (`group: family`) to automatically provision Immich accounts upon first successful SSO login.

---

### ADR: Immich Photo Management Stack Provisioning, External Library Mounting & GitOps Skill Codification

#### Context
1. **Multi-User Family Photo Strategy:** The operator required an autonomous, private, self-hosted photo management system operating in parallel with Google Photos. The solution needed to support seamless background camera roll uploads for multiple family members, private individual timelines, shared family albums, and partner sharing without cloud subscription costs.
2. **Zero-Copy Ingestion of Google Drive Archives:** A 116 GB archive (34,902 photos) freshly synced from Google Drive resided on the Btrfs storage pool (`/mnt/simba/Shared-All-Family/Photos/GoogleDrive`). The photo platform needed to index, face-tag, and search these archives without duplicating, moving, or modifying existing files on disk.
3. **Operational Discipline & Governance:** Changes to Docker Compose stacks, edge proxy rules, and dashboard configs on LXC 920 must follow strict GitOps discipline (authoring in `homelab-stacks`, pushing to GitHub, pulling on host, decoupling secrets). This workflow required permanent codification into Antigravity skills and rules.

#### Action
1. **Declarative GitOps Stack Definition (`immich/compose.yaml`):**
   * Authored `immich/compose.yaml` and `immich/.env.example` in GitOps repository `benkaboo/homelab-stacks`.
   * Deployed `immich-server:release`, `immich-machine-learning:release`, PostgreSQL with vector extensions (`pgvectors`), and Valkey (`valkey:9`).
   * Placed PostgreSQL vector database on SSD fast storage (`/opt/stacks/immich/postgres`), new phone uploads on Btrfs storage (`/mnt/simba/Shared-All-Family/Photos/Immich/Uploads`), and mounted historical Google Drive photos as a read-only external volume (`/mnt/media/GoogleDrive:ro`).
2. **Edge Proxy Ingress & Dashboard Integration:**
   * Configured Caddy routes for `photos.dixon.home` and `photos.192.168.68.175.nip.io` with internal PKI TLS and native authentication (preserving mobile app API connectivity).
   * Added Immich service tile to Homepage dashboard under Media & Entertainment.
3. **GitOps Governance & Skill Embedding:**
   * Created formal Antigravity skill `gitops-homelab` in `personal-governance/skills/gitops-homelab/SKILL.md`.
   * Created repository governance rules in `homelab-stacks/AGENTS.md`.
   * Codified Rule 6 in `Proxmox-wireguard/AGENTS.md` enforcing the GitOps deployment workflow for all LXC 920 stacks.
4. **Hydration & Deployment:**
   * Pushed GitOps updates to GitHub (`ec0f75c`, `5609dd3`), pulled on LXC 920, hydrated decoupled `.env` with secure random credentials, and successfully launched all 4 healthy containers.

#### Consequences
* **Positive:** Complete self-hosted Google Photos alternative operational with facial recognition, map view, AI search, and background mobile uploads.
* **Positive:** Historical 116 GB photo archive indexed via read-only external mount without file movement or disk duplication.
* **Positive:** Immich database and mobile uploads are automatically protected under daily Backrest snapshot plans (`stacks_and_databases` at 03:00 AM and `family_photos` at 04:00 AM).
* **Governance:** The homelab GitOps workflow is permanently embedded as a first-class skill across all future Antigravity sessions.

---

## [2026-10-04]

### ADR: Server-Side Google Drive Photo Ingestion & Backrest Family Photos Backup Plan

#### Context
1. **Cloud Photo Redundancy & Virtual File Pitfalls:** The operator maintained a ~115 GB Google Drive photo library (34,902 files in `import_onedrive/Pictures`). On the primary Windows workstation, Google Drive operates in "Stream files" mode where file metadata is represented as sparse stubs. Attempting to back up these folders using local workstation Restic/VSS creates an uncontrolled download storm filling local SSD caches (`%LOCALAPPDATA%`) and causing VSS snapshot failures.
2. **Zero-Knowledge Operator Sovereignty & Cloud Safety:** Cloud-to-NAS synchronization must guarantee that cloud photos cannot be altered or deleted. Access must be constrained strictly to read-only API scopes (`drive.readonly`) with non-destructive one-way ingestion (`rclone copy`) to prevent accidental deletion cascades.
3. **Automated Snapshot Lifecycle:** Ingested photos stored on the NAS storage pool (`/mnt/simba/Shared-All-Family/Photos`) require integration into the centralized Backrest orchestration engine to ensure point-in-time, deduplicated, encrypted restic snapshots with extended retention.

#### Action
1. **Read-Only Server-Side Ingestion Architecture:**
   * Deployed `rclone` (v1.60.1) on LXC 920 (`services`) configured with dedicated OAuth credentials enforcing `scope = drive.readonly`.
   * Created automated sync script `/home/bjm/scripts/sync-gdrive-photos.sh` using non-destructive `rclone copy` with rate-limiting pacing (`--tpslimit 8`, `--transfers 4`, `--checkers 8`) targeting `/mnt/simba/Shared-All-Family/Photos/GoogleDrive`.
   * Configured dedicated log rotation via `/etc/logrotate.d/rclone-photos-sync` for `/home/bjm/logs/rclone-photos-sync.log`.
2. **Timezone Synchronization & Systemd Automation:**
   * Synchronized LXC 920 timezone to `Australia/Melbourne (AEDT, +1100)` to eliminate clock skew with the Proxmox host (`rath15nas`) and workstation.
   * Installed and enabled systemd units `rclone-photos-sync.service` and `rclone-photos-sync.timer` scheduled to run daily at 02:00 AM AEDT with `Persistent=true`.
3. **Backrest Backup Plan Provisioning (`family_photos`):**
   * Registered declarative plan `family_photos` in Backrest (`/opt/stacks/backrest/config/config.json`) targeting `/userdata/simba/Shared-All-Family/Photos`.
   * Linked plan to encrypted repository `services` (`/mnt/backups/services`) with daily execution scheduled at 04:00 AM AEDT (`0 4 * * *`).
   * Configured rolling retention policy: 30 daily, 12 monthly, and 5 yearly snapshots.
4. **Initial Library Ingestion:**
   * Initiated initial transfer of 115.22 GiB across 34,902 objects directly into the Btrfs storage pool without workstation bandwidth or disk consumption.

#### Consequences
* **Positive:** Bypasses Windows virtual file / VSS streaming limitations, establishing direct, autonomous server-to-server photo backup.
* **Positive:** Google Drive cloud data is cryptographically protected against modification or deletion via Google API server-side enforcement of `drive.readonly`.
* **Positive:** Photos are accessible locally to family users via Samba and FileBrowser while backed up with 5-year point-in-time recovery in Backrest.
* **Operational:** LXC 920 container timezone aligned to AEDT, preventing scheduled job misalignments across the homelab fleet.

---

### ADR: Multi-Endpoint Restic Orchestration & Zero-Knowledge Server State Backups

#### Context
1. **Multi-Endpoint Consolidation:** The operator maintained independent client-side Restic backup pipelines on the primary workstation (`LENOVO16_LP`) and living-room HTPC (`rath15-htpc`) terminating on `rest-server` with `--append-only` security flags. However, because clients had no administrative rights to prune or check repositories, backups lacked automated retention lifecycle enforcement, and operators had no unified pane of glass to inspect snapshot trees.
2. **Server Microservices & Database Protection:** Stateful application data (LLDAP user directory, Authelia sessions, Dockge compose records, FileBrowser metadata, Calibre-Web app state, Uptime Kuma monitors) and decrypted `.env` secrets on LXC 920 were excluded from the `homelab-stacks` GitOps repository by design. An automated, disaster-resilient backup pipeline was required to protect this state without committing secrets to Git.
3. **Operator Sovereignty & Zero-Knowledge Encryption:** Master repository encryption keys for backup repositories must adhere to zero-knowledge principles. The operator generated and stored the master key independently in Bitwarden, ensuring the assistant/agent never had visibility into the secret key.

#### Action
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

#### Consequences
* **Positive:** Complete, automated disaster recovery established for all container services and databases without exposing secrets to Git.
* **Positive:** Operators possess a single, unified web interface to browse snapshots, perform file-level restores, and monitor storage across all three infrastructure tiers (Workstation, HTPC, Services).
* **Positive:** Automated garbage collection and pruning prevent infinite disk accumulation while guaranteeing one full year of point-in-time recovery milestones.
* **Security:** True zero-knowledge encryption maintained—master server backup key exists solely in the operator's Bitwarden vault.

---

### ADR: Backrest Backup Orchestrator Provisioning, Caddy Route & Admin Access Control

#### Context
1. **State & Database Backup Governance:** Microservices deployed in LXC 920 generate stateful SQLite databases (`users.db`, `db.sqlite3`, `dockge.db`, `filebrowser.db`, `app.db`, `kuma.db`) and decoupled secret configurations (`.env`, `oidc.key`) that are intentionally excluded from GitOps version control.
2. **Visual Inspection & Snapshot Recovery:** While the underlying backup target (`rest-server` on `rath15nas` at port 8000) provides an append-only restic repository, operators require a web interface to inspect backup status, browse file-level snapshot trees, view run-to-run diffs, and perform self-service file restores without executing manual restic CLI commands.
3. **Least Privilege Ingress:** Because backup management interfaces possess snapshot browsing and administrative configuration capabilities across the entire stack, access to the backup dashboard must be strictly enforced via Authelia SSO and restricted exclusively to the `admins` role.

#### Action
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

#### Consequences
* **Positive:** Operators now possess a centralized, intuitive web interface to orchestrate Restic snapshots, inspect backup contents, download historical files, and monitor repository deduplication health.
* **Positive:** Complete protection against unauthorized access by restricting the backup portal to authenticated users in the `admins` LDAP group.
* **Positive:** Backed source trees are mounted strictly read-only, preventing backup tools from corrupting live application databases or media pools.
* **Operational:** Operators can now initialize Restic repositories and schedule backup tasks directly from `https://backup.dixon.home`.

---

## [2026-10-03]

### ADR: Homelab GitOps Architecture & Identity Federation Foundation

#### Context
1. **Application Lifecycle Decoupling & Incus Readiness:** Container services hosted in LXC 920 were previously managed and deployed through imperative bash scripts (`01-create-lxc.sh` through `21-fix-homepage-hosts.sh`). To prepare for a seamless future migration to Incus (LXD community fork) and eliminate hypervisor lock-in, application definitions, reverse proxy rules, and configurations needed to be decoupled from Proxmox commands (`pct exec`, `pct push`) into a single declarative source of truth.
2. **Cross-Site Authentication Federation:** The operator and his brother sought to federate authentication rules between their homelabs (linking Dixon and Maslen networks across WireGuard). Both operators required the capability to collaboratively manage accounts, share access control rules, and establish mutual service failover.
3. **Resilience & Governance:** Direct synchronous authentication over a WAN WireGuard link risks locking out local users during ISP downtime. A multi-stage architecture utilizing GitOps for configuration synchronization, local LLDAP as a decoupled user directory, and dual-domain Authelia rules was determined to provide high availability with zero WAN outage dependency.

#### Action
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

#### Consequences
* **Positive:** All homelab application configurations and reverse proxy routes are now backed up offsite in an immutable, auditable Git repository.
* **Positive:** Collaborative foundation established for brother to review and contribute to shared ACL rules via Pull Requests.
* **Positive:** Provides the exact prerequisite structure needed to migrate container stacks to Incus in the future with a single `git clone`.
* **Security:** Guaranteed zero-secret leakage into version control through template abstraction and strict git ignore rules.
* **Operational:** Stacks will transition to Git-driven deployment via deploy keys rather than imperative host scripts.

---

### ADR: LLDAP Identity Provider Provisioning, GitOps Deploy Key & Authelia Backend Cutover

#### Context
1. **Directory Consolidation & Multi-User Access:** Authelia was previously operating with a static YAML file (`users_database.yml`) for user accounts. To allow the operator and his brother to manage accounts independently and provide role-based access to homelab services (Jellyfin, Books, Audiobookshelf, Files), a lightweight, standards-compliant LDAP directory was required.
2. **E-Reader & Non-Browser Clients:** Media and e-book services (Calibre-Web) provide OPDS catalogs for hardware e-readers (Kobo, Kindle) that cannot execute browser JavaScript or handle forward-auth web redirects. A native LDAP directory service enables direct HTTP Basic Auth verification for e-readers while preserving web SSO for desktop and mobile browsers.
3. **Automated Server Pull Authentication:** LXC 920 required read-only access to pull updates from the private `benkaboo/homelab-stacks` GitHub repository without storing personal GitHub account credentials or write tokens on the production container.

#### Action
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

#### Consequences
* **Positive:** Centralized LDAP identity directory established for all current and future homelab services.
* **Positive:** Authelia web portal, Caddy forward-auth, and Jellyfin OIDC authenticate seamlessly against LLDAP credentials.
* **Positive:** Hardware e-readers (Kobo, Kindle) can connect directly to Calibre-Web's OPDS catalog using LDAP credentials without browser SSO redirection failures.
* **Positive:** Autonomous, credential-free GitOps deployments enabled on LXC 920 via read-only deploy key.
* **Operational:** Production `/opt/stacks` now synchronized via `git pull` from GitHub repository `homelab-stacks`.

---

## [2026-09-20]

### ADR: Home Assistant OS (HAOS) Virtual Machine (VM 940) Provisioning & Hybrid Smart Home Architecture

#### Context
1. **Cloud Fragility & Offline Outage Impact:** The operator's home automation setup relied on Google Home and Google Nest devices. During intermittent internet outages, all device-to-device communication and smart home controls were severed due to Google Home's cloud-dependent architecture.
2. **Hardware Preservation & Hybrid Strategy:** Operator owns multiple Google Nest Audio, Nest Mini, and smart display devices. Replacing all hardware would be disruptive and costly. An architectural evaluation selected a hybrid topology: Home Assistant serves as the local, offline-resilient automation engine and state coordinator, while Google Nest speakers are retained as local Cast media targets and cloud voice input endpoints.
3. **Hypervisor Sizing & Isolation:** Proxmox host `rath15nas` maintains ~26 GB of available RAM. Deploying Home Assistant as an official KVM virtual machine (HAOS) rather than a Docker container in LXC 920 guarantees access to the official Supervisor, one-click Add-on Store, seamless USB passthrough for future Zigbee/Z-Wave coordinators, and isolated networking. A conservative allocation of 2 GB RAM and 2 vCPUs preserves >22 GB host memory headroom while remaining expandable on demand.

#### Action
1. **Automation Scripting:**
   * Authored [`scripts/setup-haos-vm.sh`](scripts/setup-haos-vm.sh) implementing automated discovery of the latest HAOS release from GitHub, UEFI OVMF initialization, `q35` machine profile creation, disk import to `local-lvm`, and automatic volume resize to 32 GB.
   * Authored PowerShell workstation orchestrator [`scripts/deploy-haos-vm.ps1`](scripts/deploy-haos-vm.ps1) for authenticated staging and interactive `sudo` execution.
2. **Network Design:**
   * Configured primary network interface attached to `vmbr0` (Management LAN `192.168.68.0/24`).
   * Placing the VM directly in the same Layer 2 broadcast domain as Google Nest speakers enables zero-configuration mDNS and Google Cast protocol discovery without requiring multicast forwarding proxies.
3. **Ingress & Reverse Proxy Routing:**
   * Authored and executed [`scripts/configure-caddy-ha.sh`](scripts/configure-caddy-ha.sh) and [`scripts/deploy-caddy-ha.ps1`](scripts/deploy-caddy-ha.ps1) on LXC 920.
   * Configured Caddy routes for `ha.192.168.68.175.nip.io` and `ha.dixon.home` with automated TLS termination and websocket proxying to `192.168.68.170:80`.
   * Authorized proxy IP `192.168.68.175` under Home Assistant's trusted proxies.
4. **Architecture Synchronization:**
   * Updated [`ARCHITECTURE.md`](ARCHITECTURE.md) Section 4 with VM 940 specifications, Caddy reverse proxy routing, and automation scripts.

#### Consequences
* **Positive:** Unlocks 100% local, offline-capable smart home automations and sensor coordination independent of ISP uptime.
* **Positive:** Retains full utility of existing Google Nest Audio/Mini devices as local media players and Text-to-Speech (TTS) notification targets.
* **Positive:** Access to full Home Assistant Supervisor and Add-on ecosystem (Mosquitto MQTT, Zigbee2MQTT, ESPHome).
* **Operational:** Minimal host resource consumption (~2 GB RAM, 2 vCPUs), leaving >22 GB RAM free for LXC 920 and host storage caching.

---

### ADR: WireGuard Endpoint Role Reversal to Ben Dedicated Static IPv4 (`157.85.240.10:51820`)

#### Context
1. **Peer Static IP Loss & IPv4 DNS Deprecation:** The remote peer router (Brother) lost its static public IPv4 address, and its dynamic DNS domain (`maslen.id.au`) transitioned exclusively to an IPv6 `AAAA` record (`2401:d002:b504:3300::1`), dropping all IPv4 records. Because `rath15nas` was acting as an outbound initiator seeking `maslen.id.au:51820`, the site-to-site VPN link experienced a ~1.7-day outage.
2. **Asymmetric Network Topology:** Ben's Neptune Internet connection (`AS151660`) was validated to possess a dedicated, permanent static public IPv4 address (`157.85.240.10`) with PTR `ip-157.85.240.10.neptune.net.au`. Reversing endpoint roles allows the brother to connect outbound from behind dynamic IP or CGNAT, relying on WireGuard dynamic endpoint roaming.

#### Action
1. **Proxmox Host Reconfiguration (`rath15nas`):**
   * Staged and executed [`scripts/reconfigure-wireguard-listener.sh`](scripts/reconfigure-wireguard-listener.sh).
   * Updated `/etc/wireguard/wg0.conf` to set `ListenPort = 51820` under `[Interface]`.
   * Removed stale outbound `Endpoint = maslen.id.au:51820` under `[Peer]`, configuring `rath15nas` as a passive listening endpoint.
   * Restarted `wg-quick@wg0.service`. Verified socket binding on `0.0.0.0:51820` and `[::]:51820`.
2. **Deco M9 Router Port Forwarding:**
   * Configured external port forward on TP-Link Deco M9 (`192.168.68.1`): `UDP 51820` $\rightarrow$ `192.168.68.169:51820`.
3. **Peer Coordination:**
   * Provided drop-in configuration for remote peer pointing to `Endpoint = 157.85.240.10:51820` with `PersistentKeepalive = 25`.
4. **Verification:**
   * Handshake established immediately (`wg show wg0` confirmed roaming endpoint `115.70.61.168:50284`).
   * ICMP ping across tunnel to `10.10.0.1` succeeded (0% packet loss, ~19ms latency).
   * Cross-subnet ping to remote LAN `192.168.6.1` succeeded from both `rath15nas` (~19ms) and Windows workstation (~26ms).

#### Consequences
* **Positive:** Site-to-site VPN tunnel and cross-subnet routing (`192.168.6.0/24`) are fully restored.
* **Positive:** Brother is completely insulated from future ISP dynamic IP or CGNAT changes; WireGuard automatically updates its roaming endpoint upon receiving keepalive packets.
* **Security:** Public attack surface remains strictly bounded to a single silent UDP port (`51820`).

---

### ADR: Mobile Road-Warrior Client Provisioning (`10.10.0.5/32`) & Split-Tunneling

#### Context
Operator required secure, encrypted remote access to homelab services (Jellyfin, Books, Proxmox GUI, Samba shares, and remote brother network) while away from home on mobile cellular or untrusted Wi-Fi.

#### Action
1. **Provisioning Script:** Created [`scripts/add-wireguard-client.sh`](scripts/add-wireguard-client.sh) and [`scripts/deploy-add-client.ps1`](scripts/deploy-add-client.ps1).
2. **Key Generation & Dynamic Peer Registration:**
   * Generated dedicated Curve25519 keypair on `rath15nas`.
   * Dynamically registered peer `10.10.0.5/32` using `wg set wg0 peer <pubkey> allowed-ips 10.10.0.5/32` with zero downtime to the active brother tunnel.
   * Persisted peer block in `/etc/wireguard/wg0.conf`.
3. **LAN Egress NAT Masquerade:**
   * Added `iptables -t nat -A POSTROUTING -s 10.10.0.0/24 -o vmbr0 -j MASQUERADE` and persisted rule in `wg0.conf` `PostUp`/`PostDown`.
4. **Client Profile & Terminal QR Code:**
   * Generated split-tunnel client configuration with `AllowedIPs = 192.168.68.0/24, 192.168.6.0/24, 10.10.0.0/24` and DNS set to AdGuard Home (`192.168.68.175`).
   * Rendered ANSI UTF-8 QR code in terminal using `qrencode`.
   * Securely wiped client private keys and temporary profiles from server disk post-scan.

#### Consequences
* **Positive:** Operator can securely connect from anywhere via official WireGuard app on Google Pixel phone.
* **Positive:** Split-tunnel design routes homelab and DNS traffic over VPN while preserving direct cellular speeds for general internet streaming.
* **Positive:** Network-wide ad-blocking and `*.dixon.home` resolution are active on mobile data via AdGuard Home.

---

### ADR: Homepage Dashboard ("Dixon Fleet") & Uptime Kuma 24/7 Monitoring Deployment

#### Context
Operator and family required a unified, clean application launcher (matching brother's "Maslen Fleet" dashboard) and 24/7 service uptime monitoring with incident alerting.

#### Action
1. **Uptime Kuma Deployment:**
   * Provisioned `louislam/uptime-kuma:1` Docker stack under `/opt/stacks/uptime-kuma/compose.yaml` attached to `gateway_net`.
   * Configured Caddy routes at `https://status.dixon.home` and `https://status.192.168.68.175.nip.io` (plain HTTP at `http://status.192.168.68.175.nip.io`).
2. **Homepage Dashboard Deployment:**
   * Provisioned `ghcr.io/gethomepage/homepage:latest` Docker stack under `/opt/stacks/homepage/compose.yaml` attached to `gateway_net`.
   * Configured read-only bind mount `/var/run/docker.sock:/var/run/docker.sock:ro` for live container health telemetry and CPU/RAM telemetry.
   * Set `HOMEPAGE_ALLOWED_HOSTS=*` in container environment to support Caddy reverse proxy headers.
   * Configured Caddy routes at `https://home.dixon.home` and `https://home.192.168.68.175.nip.io` (plain HTTP at `http://home.192.168.68.175.nip.io`).
   * Pre-populated service catalog with local services (Jellyfin, Audiobookshelf, Calibre-Web, Proxmox, Dockge, FileBrowser, AdGuard, Uptime Kuma) and remote brother services (Jellyfin 2, Books 2, Maslen Fleet).
3. **Local PKI Distribution Endpoint:**
   * Configured Caddy endpoint `http://pki.192.168.68.175.nip.io/root.crt` to facilitate downloading Caddy's root CA certificate for client device trust on Android/iOS.
4. **FileBrowser Database Permission Remediation:**
   * Diagnosed container restart loop caused by `Error: open /database/filebrowser.db: permission denied`.
   * Set database file permissions to `0664` owned by `1001:1001` (matching unprivileged container UID), restoring FileBrowser to `Up (healthy)`.

#### Consequences
* **Positive:** Centralized, responsive start page ("Dixon Fleet") provides single-click access to all homelab and remote brother services with live status dots.
* **Positive:** 24/7 monitoring active via Uptime Kuma for continuous health checks and alerting.
* **Positive:** All 11 Docker containers on LXC 920 are confirmed healthy.

## [2026-09-13]

### ADR: Dynamic WireGuard Endpoint Migration (`maslen.id.au`) & DNS Resolver Remediation

#### Context
1. **Remote Peer ISP Migration:** The remote WireGuard peer router changed ISP, resulting in a public IP transition from `203.132.95.12` to `157.85.240.12` (managed via dynamic DNS hostname `maslen.id.au`). Because `/etc/wireguard/wg0.conf` on `rath15nas` had the deprecated IP hardcoded as its peer endpoint, the site-to-site VPN connection dropped and failed to renegotiate handshakes.
2. **Broken Host DNS Resolver:** During incident triage, `/etc/resolv.conf` on `rath15nas` was found to be pointing exclusively to `119.40.106.35` (Superloop upstream DNS), which refused recursive DNS queries following the network migration. Consequently, the host could not resolve any hostnames (including `maslen.id.au`), preventing dynamic DNS resolution upon service restart.

#### Action
1. **DNS Resolver Remediation:**
   * Backed up `/etc/resolv.conf` to a timestamped backup file.
   * Updated `/etc/resolv.conf` to declare the local LAN gateway (`192.168.68.1`) and Cloudflare public resolver (`1.1.1.1`) alongside the local domain search (`benevolency.com`).
   * Validated hostname resolution: `maslen.id.au` dynamically resolved to `157.85.240.12`.
2. **WireGuard Configuration Update:**
   * Backed up `/etc/wireguard/wg0.conf` to a timestamped backup file.
   * Replaced the hardcoded endpoint (`203.132.95.12:51820`) with dynamic hostname `Endpoint = maslen.id.au:51820`.
   * Preserved strict file permissions (`chmod 600 /etc/wireguard/wg0.conf`).
3. **Service Reload & Automated Verification:**
   * Restarted `wg-quick@wg0.service`.
   * Confirmed successful WireGuard handshake and active traffic counters via `wg show wg0`.
   * Validated end-to-end ICMP ping across the tunnel to `10.10.0.1` (0% packet loss, ~19ms latency) and remote subnet `192.168.6.1` (0% packet loss, ~22ms latency).
4. **Remediation Scripting:**
   * Authored automated deployment scripts [`scripts/update-wireguard-endpoint.sh`](scripts/update-wireguard-endpoint.sh) and [`scripts/update-wireguard-endpoint.ps1`](scripts/update-wireguard-endpoint.ps1) adhering to Rule 5 staging patterns.

#### Consequences
* **Positive:** WireGuard site-to-site VPN link and cross-subnet routing (`192.168.6.0/24`) are fully restored.
* **Positive:** Future IP changes on the remote peer will automatically be absorbed upon interface restart or DNS cache refresh via dynamic hostname resolution.
* **Positive:** `rath15nas` hypervisor host DNS resolution is stabilized with dual redundant resolvers.

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

### ADR: WireGuard Boot Persistence & Cross-Subnet Gateway Routing

#### Context
1. **Reboot Persistence:** WireGuard was previously started interactively/manually without systemd service management. On host reboot, the tunnel would not automatically reconnect.
2. **Cross-Subnet Access:** Operator workstations on the local LAN (`192.168.68.0/24`) need to reach the remote peer network (`192.168.6.0/24`) across the WireGuard tunnel. The Proxmox host lacked kernel packet forwarding and NAT masquerading, causing packets to be dropped or rejected due to asymmetric routes and WireGuard cryptokey routing constraints.

#### Action
1. **Phase 1 (Persistence):**
   * Enabled `wg-quick@wg0.service` in systemd (`systemctl enable wg-quick@wg0`) to ensure tunnel creation on boot milestone.
   * Validated tunnel endpoint connectivity (`ping -c 3 10.10.0.1`) and handshake status.
2. **Phase 2 (Cross-Subnet Gateway):**
   * Enabled IPv4 kernel forwarding (`sysctl -w net.ipv4.ip_forward=1`).
   * Configured NAT masquerading on the WireGuard egress interface (`iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE`).
   * Configured stateful filter forwarding rules (`iptables -A FORWARD -d 192.168.6.0/24 -o wg0 -j ACCEPT` and `iptables -A FORWARD -i wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT`).
   * Defined static route on client workstation: `route -p add 192.168.6.0 mask 255.255.255.0 192.168.68.169`.
3. **Phase 3 (Persistence Lock-In & Privilege Revocation):**
   * Appended `PostUp` and `PostDown` hooks into `/etc/wireguard/wg0.conf` for automatic iptables lifecycle management.
   * Persisted kernel forwarding across boots via `/etc/sysctl.d/99-wireguard-forwarding.conf`.
   * Revoked temporary scoped permissions (`/etc/sudoers.d/agy-wireguard`), returning `agy-auditor` strictly to least-privilege read-only inspection (`/etc/sudoers.d/agy-readonly`).
   * Tagged release: `v1.0-wireguard-routing`.

#### Consequences
* **Positive:** Complete host-side WireGuard and routing lifecycle automatically persists across reboots.
* **Positive:** Local LAN clients can transparently route traffic to `192.168.6.0/24` via Proxmox (`192.168.68.169`) without requiring changes to the remote peer's router or AllowedIPs list.
* **Security:** `agy-auditor` credentials and privileges are strictly locked down to read-only diagnostics; secrets remain isolated from automation.

### ADR: Multi-Device Btrfs RAID1 Pool, Windows-Optimized Samba Share, and AGY Host Runtime

#### Context
1. **Storage Infrastructure:** The host had unformatted or legacy single-disk partitions (`sdd1`, `sde1`, `sdc1`). Resilient, self-healing shared network storage was required across heterogeneous drives (4 TB Seagate IronWolf, 4 TB WD Red, 3 TB WD Purple).
2. **Network File Sharing:** Local workstations on the network are predominantly Windows clients requiring fast, reliable file access with support for Windows metadata, file locking, and alternate data streams.
3. **Host Administration:** Operating the Proxmox server directly benefits from a local AI assistant runtime on the hypervisor host in addition to the remote workstation agent.

#### Action
1. **Btrfs RAID1 Storage Pool:**
   * Formatted `/dev/sdd1`, `/dev/sde1`, and `/dev/sdc1` as a Btrfs `raid1` array (data & metadata) mounted at `/mnt/data`.
   * Created dedicated subvolumes: `/mnt/data/@simba`, `/mnt/data/@shares`, and `/mnt/data/@backups`.
   * Configured `/etc/fstab` persistence with options `defaults,noatime,compress=zstd:1,space_cache=v2,nofail,x-systemd.device-timeout=15s`.
2. **Windows-Optimized Samba (SMB3) Service:**
   * Installed `samba` and configured `/etc/samba/smb.conf` with Windows-first tuning (`SMB3`, `server multi channel support`, `aio read/write size = 1`, `use sendfile = yes`, `store dos attributes = yes`, `ea support = yes`, `vfs objects = streams_xattr acl_xattr`).
   * Configured share `[simba]` mapped to `/mnt/data/@simba`, restricted to authenticated user `bjm` with forced `0664`/`0775` permission masking.
   * Enabled and started `smbd.service` via systemd.
3. **Deployment Automation:**
   * Added interactive variable-prompting deployment scripts: [`scripts/deploy-samba.ps1`](scripts/deploy-samba.ps1) (PowerShell) and [`scripts/setup-samba.sh`](scripts/setup-samba.sh) (Bash).
4. **Antigravity Host Runtime:**
   * Installed Google Antigravity CLI (`agy` v1.1.27) directly on the Proxmox host (`~/.local/bin/agy`).

#### Consequences
* **Positive:** ~4.95 TB of resilient, self-healing mirrored storage with 1-disk fault tolerance across mismatched disk capacities.
* **Positive:** Native, high-performance file sharing for Windows clients with zero permission friction.
* **Positive:** Local `agy` presence on the Proxmox hypervisor enables direct on-host troubleshooting, while remote operations continue through the least-privilege `agy-auditor` SSH alias.

### ADR: Dedicated Docker Services Container (LXC 920), Reverse Proxy Gateway, and Authelia SSO Portal

#### Context
1. **Service Isolation & Lifecycle:** Running self-hosted media and application stacks (Dockge, Caddy, Authelia, Jellyfin, Calibre-Web) directly on the Proxmox hypervisor (`rath15nas`) compromises host stability, security, and backup simplicity. A dedicated, lightweight, unprivileged environment was required.
2. **Access Control & User Experience:** Local network clients (including family members using the Home Theatre PC and Windows Samba shares) must not have their existing network connectivity or file access disrupted. However, web interfaces for management, media, and tools need centralized Single Sign-On (SSO) and Two-Factor Authentication (2FA) without exposing unauthenticated ports to the LAN or internet.
3. **Storage & Performance Requirements:** Application metadata, databases (e.g. SQLite), and Docker overlay files require high-IOPS NVMe/SSD storage (`local-lvm`), while bulk media datasets (`Media/`, `Books/`) reside on the resilient Btrfs RAID1 storage pool mounted at `/mnt/data/@simba`.

#### Action
1. **LXC Container Provisioning (`01-create-lxc.sh`, `02-bindmount-and-start.sh`):**
   * Created unprivileged Ubuntu 24.04 LTS container `920` (`services`) with 4 vCPUs, 4096 MB RAM, and 32 GB SSD root disk on `local-lvm`.
   * Assigned static IP `192.168.68.175/24` with gateway `192.168.68.1` bridged to `vmbr0`.
   * Enabled container features `nesting=1,keyctl=1` to support Docker Engine and secure system keyrings.
   * Bind-mounted host Btrfs subvolume `/mnt/data/@simba` to container `/mnt/simba` (`mp0`), granting the container direct filesystem access to `Books/`, `Documents/`, `Media/`, and `Scripts/`.
2. **Docker Runtime & Web Stack Management (`03-install-docker.sh`, `04-deploy-dockge.sh`):**
   * Installed official Docker Engine (`v29.8.0`) and Docker Compose (`v5.5.1`) inside LXC 920.
   * Deployed Dockge on host port `5001` with stack root configured at `/opt/stacks` on high-speed SSD storage.
3. **Edge Reverse Proxy & Internal Network (`05-deploy-caddy.sh`):**
   * Created internal Docker bridge network `gateway_net` for secure inter-container routing.
   * Deployed Caddy reverse proxy container listening on host ports `80` and `443` (TCP/UDP).
4. **Authelia SSO & 2FA Portal (`06-deploy-authelia.sh`):**
   * Deployed Authelia container attached to `gateway_net` with external port `9091`.
   * Configured wildcard domain `192.168.68.175.nip.io` for seamless cross-subdomain session cookie sharing across LAN clients without client-side `hosts` modification.
   * Generated cryptographically secure secrets (`JWT_SECRET`, `SESSION_SECRET`, `STORAGE_KEY`) and Argon2id password hash for administrator `bjm`.
   * Backed configuration and SQLite database in persistent directories `/opt/stacks/authelia/config/` and `/opt/stacks/authelia/data/`.
   * Automated configuration validation with `authelia config validate` and validated `/api/health` returns `{"status":"ok"}`.

#### Consequences
* **Positive:** Complete isolation of Docker containers inside an unprivileged LXC guest; hypervisor OS remains pristine.
* **Positive:** Family network traffic (HTPC, Windows file shares) remains entirely untouched and operational.
* **Positive:** High I/O performance achieved through SSD-backed Docker stacks paired with high-capacity Btrfs storage for media.
* **Security:** All sensitive materials (passwords, JWT secrets, session keys) are generated on-demand at deployment time and excluded from Git version control. Reproducible deployment scripts are maintained in [`scripts/lxc-setup/`](scripts/lxc-setup/).

### ADR: Media Applications Deployment (Jellyfin & Calibre-Web) on LXC 920

#### Context
1. **Media Streaming:** Living-room clients, mobile devices, and smart TVs require high-performance, direct-play and hardware-assisted media streaming without needing raw SMB network drive access.
2. **Digital Library Management:** An accessible e-book library is required for reading, metadata management, and conversion on local devices without exposing raw storage filesystems to unauthenticated clients.
3. **Container Storage Architecture:** Both stacks require high-speed configuration databases on NVMe/SSD storage while reading bulk libraries from the resilient Btrfs storage pool (`/mnt/simba`).

#### Action
1. **Jellyfin Media Server Deployment (`08-deploy-jellyfin.sh`):**
   * Deployed official `jellyfin/jellyfin:latest` stack in `/opt/stacks/jellyfin/compose.yaml` on host port `8096`.
   * Bind-mounted `/mnt/simba/Media` as read-only (`:ro`) into container `/media`.
   * Routed HTTPS endpoint `https://jellyfin.192.168.68.175.nip.io` via Caddy with native authentication to support smart TV and mobile client apps.
2. **Calibre-Web E-Book Library Deployment (`09-deploy-calibre-web.sh`):**
   * Deployed `lscr.io/linuxserver/calibre-web:latest` in `/opt/stacks/calibre-web/compose.yaml` on host port `8083`.
   * Seeded official starter `metadata.db` into `/mnt/simba/Books/metadata.db`.
   * Configured dynamic DOCKER_MODS (`linuxserver/mods:universal-calibre`) with polling retry validation for automated e-book cover conversion and format processing.
   * Routed HTTPS endpoint `https://books.192.168.68.175.nip.io` via Caddy with Authelia forward authentication.

#### Consequences
* **Positive:** High-performance media playback and digital reading portals available across the home LAN.
* **Positive:** Bulk media datasets remain protected in read-only mode for streaming, preventing accidental deletion from client apps.

### ADR: Dedicated HTPC Service Account and Isolated [Media] Samba Share

#### Context
1. **Optical Media Ripping Workflow:** The Home Theatre PC (`rath15-htpc`, `192.168.68.162`) requires direct filesystem write access to the media repository (`/mnt/simba/Media`) to dump DVD and Blu-ray rips (MakeMKV, Handbrake) directly into `Movies`, `TV Shows`, and `Music`.
2. **Windows Multi-Session Collision:** Windows clients permit only one authenticated user context per target server IP/hostname. When the HTPC connected anonymously or with local machine credentials (due to Samba's `map to guest = Bad User`), subsequent attempts to authenticate to `[simba]` as `bjm` triggered client-side Windows error 1219 (*"Multiple connections to a server or shared resource by the same user, using more than one user name, are not allowed"*).
3. **Least Privilege & Ownership Isolation:** Granting the living-room HTPC full access to the root `[simba]` share exposed personal backups and documents. Furthermore, adding `htpc` to the operator's User Private Group (`bjm`) violated least privilege.

#### Action
1. **Isolated Linux Service Account:**
   * Created dedicated system user `htpc` (UID 1003) on `rath15nas` with disabled interactive login shell (`/usr/sbin/nologin`), no home directory (`-M`), and standard membership in primary group `users` (GID 100).
   * User `htpc` is explicitly excluded from the administrative `bjm` and `sudo` groups.
2. **Dedicated `[Media]` Share Configuration (`smb.conf`):**
   * Added share `[Media]` mapped to `/mnt/simba/Media` restricted to `valid users = bjm, htpc`.
   * Configured Samba identity forcing: `force user = bjm` and `force group = bjm`.
   * Configured creation masks `force create mode = 0664` and `force directory mode = 0775`.
3. **Deployment Automation:**
   * Created [`scripts/setup-htpc-media-share.sh`](scripts/setup-htpc-media-share.sh) and PowerShell wrapper [`scripts/deploy-htpc-media.ps1`](scripts/deploy-htpc-media.ps1) with automated configuration backup and service reload (`systemctl reload smbd.service`).
4. **Client-Side Mount Configuration:**
   * Cleared stale anonymous sessions on HTPC and registered dedicated credentials in Windows Credential Manager:
     `cmdkey /add:192.168.68.169 /user:htpc /pass:<secret>`
     `net use M: \\192.168.68.169\Media /persistent:yes`

#### Consequences
* **Positive:** Seamless DVD ripping directly to `M:\Movies`, `M:\TV Shows`, and `M:\Music` without exposing personal files or backups in `/mnt/simba`.
* **Positive:** All files created by the HTPC are written on disk as `bjm:bjm`, eliminating file-ownership discrepancies with the operator's primary workstation.
* **Positive:** Permissions `0664`/`0775` guarantee that the unprivileged Jellyfin container (LXC 920) can read and index newly ripped media immediately.
* **Positive:** Client-side Windows session conflicts are permanently resolved via dedicated Credential Manager mapping.
* **Security:** `htpc` has zero SSH or terminal access to the Proxmox hypervisor.

## [2026-09-07]

### ADR: FileBrowser Web Manager, AdGuard Home Local DNS, and `*.dixon.home` Dual-Stack Routing

#### Context
1. **Local Domain Ergonomics & High Privacy:** Navigating to homelab services required memorizing long IP-based domains (`https://<service>.192.168.68.175.nip.io`), which depended on public cloud DNS resolution and lacked privacy. The operator required human-friendly local naming (`*.dixon.home`) with zero external DNS leakage and network-wide ad blocking.
2. **Browser & SSO Domain Hierarchy:** Modern web browsers (Chromium, Gecko, WebKit) and Authelia SSO enforce cookie security specifications prohibiting single-label domain cookies (`dixon`). A multi-label internal domain (`dixon.home`) is required to enable cross-subdomain SSO session persistence.
3. **Web-Based Storage Management:** The operator required a lightweight web file manager to browse, upload, download, and organize files across `/mnt/simba` (`Books`, `Documents`, `Media`, `Scripts`, `Shared-All-Family`) without requiring Samba client configuration on every device.

#### Action
1. **FileBrowser Deployment (`10-deploy-filebrowser.sh`):**
   * Deployed `filebrowser/filebrowser:latest` in `/opt/stacks/filebrowser/compose.yaml` on host port `8082`.
   * Bind-mounted `/mnt/simba` into `/srv` with permissions `1000:1000`.
   * Enforced minimum 12-character administrative credential policy (`MediaAdmin2026!`).
   * Integrated into Caddy with Authelia forward authentication (`import authelia-auth`).
2. **AdGuard Home Deployment (`12-deploy-adguard.sh`):**
   * Deployed `adguard/adguardhome:latest` in `/opt/stacks/adguard/compose.yaml` with host port `53` (TCP/UDP) and initial wizard on port `3000`.
   * Configured `systemd-resolved` stub listener deactivation on host `0.0.0.0:53` while preserving PVE upstream resolution via `/etc/resolv.conf`.
   * Initialized administrative portal (`dixon_admin`) and configured wildcard DNS rewrite `*.dixon.home` $\rightarrow$ `192.168.68.175`.
3. **Dual-Stack Caddy & Multi-Domain Authelia SSO (`13-configure-dixon-home.sh`):**
   * Configured Authelia `session.cookies` for multi-domain support (`dixon.home` and `192.168.68.175.nip.io`) and added access control rules for `auth.dixon.home` (bypass) and `*.dixon.home` (one_factor).
   * Configured Caddy `(authelia-auth)` forward-auth snippet to dynamically handle redirect URLs based on the incoming request domain.
   * Updated Caddy site blocks to serve both `.dixon.home` and `.192.168.68.175.nip.io` with automatic internal PKI TLS certificates.
   * Validated HTTPS routes: `auth`, `dockge`, `jellyfin`, `books`, `files`, and `adguard`.

#### Consequences
* **Positive:** Clean, intuitive, memorable URLs across all home services (`https://jellyfin.dixon.home`, `https://files.dixon.home`, `https://books.dixon.home`, etc.).
* **Positive:** 100% offline resolution; services remain fully operational and resolvable even during complete internet connectivity outages.
* **Positive:** Network-wide ad and telemetry blocking active for all devices querying AdGuard DNS (`192.168.68.175`).
* **Positive:** Zero breaking changes; legacy `*.192.168.68.175.nip.io` URLs remain fully functional as fallbacks.
* **Security:** No internal network records, hostnames, or private IPs leaked to public DNS. All sensitive credentials preserved outside version control.

### ADR: Revocation of Root SSH on LXC 920 and Deployment of Least-Privilege Read-Only Auditor (`services-agent`)

#### Context
1. **Unintended Root Privilege Surface:** During initial container provisioning (`01-create-lxc.sh`), the operator's primary workstation SSH key was injected into `/root/.ssh/authorized_keys` inside LXC 920 (`services`, `192.168.68.175`). This inadvertently allowed direct root SSH mutation by automation agents from the operator's workstation, violating the intended boundary where all mutations must be executed strictly by the human operator via Proxmox (`pct exec`).
2. **Telemetry & Diagnostic Requirement:** The agent requires read-only inspection access to Docker containers (`docker ps`, `docker logs`, `docker inspect`), network sockets (`ss`), and service unit health (`systemctl status`) to diagnose issues without requiring administrative passwords or interactive operator intervention.

#### Action
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

#### Consequences
* **Positive:** Complete least-privilege alignment across both hypervisor (`rath15nas-agent`) and container (`services-agent`).
* **Security:** Agent has zero root or mutating capabilities on any host. All container mutations require operator-reviewed scripts executed via `sudo pct exec 920`.
* **Operational:** Diagnostic telemetry, container states, and logs remain seamlessly inspectable non-interactively.

### ADR: Jellyfin OpenID Connect (OIDC) Single Sign-On Integration via Authelia

#### Context
1. **Application-Level Authentication vs Reverse Proxy Forward-Auth:**
   * Living-room streaming devices, specifically the Sony Android TV client and mobile Jellyfin apps, break when HTTP reverse-proxy forward-auth (`import authelia-auth`) is placed in front of the Jellyfin endpoint. Client apps do not handle HTTP 302 redirects to web login forms or interactive 2FA portals, and Jellyfin's native Quick Connect mechanism requires unintercepted direct API access.
   * Single Sign-On (SSO) was required for browser-based users without compromising direct API access, Quick Connect, or hardware playback for dedicated smart TV clients.
2. **Container Networking & PKI Trust Store Constraints:**
   * Docker containers on internal bridges inside LXC 920 do not resolve LAN domains like `auth.dixon.home` via the local subnet gateway router (`192.168.68.1`).
   * Caddy's internal automated TLS (`tls internal`) issues self-signed CA certificates that are not trusted by default inside .NET runtime environments (Jellyfin), producing `PartialChain` certificate validation failures when making backend OIDC discovery requests to `https://auth.dixon.home/.well-known/openid-configuration`.
3. **OIDC Client & Protocol Quirks:**
   * `jellyfin-plugin-sso` (v4.0.0.4) implements Pushed Authorization Requests (PAR) using `client_secret_basic` but exchanges authorization codes at the token endpoint via `client_secret_post`, resulting in client authentication mismatches if PAR is enforced.
   * The plugin's role claim parser expects discrete role claims; comma-concatenating allowed groups within a single XML element causes authentication rejections.

#### Action
1. **Authelia OIDC Provider & Secret Injection (`configuration.yml` & `compose.yaml`):**
   * Generated dedicated 4096-bit RSA signing key (`/opt/stacks/authelia/config/oidc.key`) with restricted permissions (`chmod 600`).
   * Registered OIDC client `jellyfin` supporting `client_secret_post` authorization code flow targeting redirect URI `https://jellyfin.dixon.home/sso/OID/redirect/authelia`.
   * Declared `X_AUTHELIA_CONFIG_FILTERS=template` in `compose.yaml` to dynamically inject file-based secrets via `{{ secret "/config/oidc.key" | mindent 10 "|" | msquote }}` without exposing raw key contents in version control.
2. **Internal DNS & TLS Trust Store Mounting:**
   * Added `extra_hosts: ["auth.dixon.home:192.168.68.175"]` to `/opt/stacks/jellyfin/compose.yaml` for instantaneous container-to-container DNS resolution.
   * Extracted Caddy's internal root certificate authority (`caddy.crt`) to the host trust store (`/usr/local/share/ca-certificates/`) and executed `update-ca-certificates`.
   * Mounted the updated certificate bundle into Jellyfin as `/etc/ssl/certs/ca-certificates.crt:ro`.
3. **Jellyfin SSO Plugin Configuration (`SSO-Auth.xml`):**
   * Configured `SSO-Auth` plugin (v4.0.0.4) with Authelia OpenID endpoints.
   * Set `<DisablePushedAuthorization>true</DisablePushedAuthorization>` to bypass PAR and maintain protocol consistency on `client_secret_post`.
   * Set `<EnableAuthorization>false</EnableAuthorization>` to delegate access gatekeeping to Authelia while assigning administrator privileges via `<AdminRoles><string>admins</string></AdminRoles>`.
4. **Live Verification:**
   * Confirmed user `bjm` (`Ben Maslen`) authenticated via SSO with full administrative and transcoding policies applied.
   * Validated live media playback (HLS transcoding via Jellyfin FFmpeg) and verified zero regressions for direct TV streaming and Quick Connect.

#### Consequences
* **Positive:** Centralized single sign-on authentication for Jellyfin web sessions using unified homelab Authelia credentials.
* **Positive:** Native smart TV apps, Android TV, Quick Connect, and mobile streaming clients remain completely functional without HTTP 302 redirect collisions.
* **Positive:** Automated mapping of Authelia `admins` group to Jellyfin administrative privileges.
* **Security:** Private keys and client secrets are maintained with strict filesystem permissions (`chmod 600`) and isolated from Git repositories.

### ADR: Audiobookshelf Audiobook & Podcast Server Deployment on LXC 920

#### Context
1. **Dedicated Spoken-Word Media Management:** The homelab required an accessible, high-performance platform for managing audiobooks and podcasts with progress synchronization across web browsers, e-readers, and dedicated mobile apps (iOS and Android).
2. **Storage Architecture & SMB Integration:** Media files need to reside on the resilient Btrfs RAID1 storage pool (`/mnt/data/@simba/Media`) while application metadata and SQLite databases require high-IOPS NVMe/SSD storage (`/opt/stacks/audiobookshelf`). Rather than creating a disjoint root share, nesting `Audiobooks` and `Podcasts` inside `/mnt/simba/Media` allows direct drag-and-drop ingestion via Windows SMB (`\\rath15nas\Media` or `M:\`) alongside `Movies`, `Music`, and `TV Shows`.
3. **Unprivileged Container Permission Boundaries:** Container LXC 920 is an unprivileged container (UID mapping 100000+). Initializing storage directories from inside the container (`pct exec`) triggers permission denial against host-owned directories (`bjm:bjm`, mode 775). Provisioning must occur directly on the host with open write permissions (`0777`) so container processes and SMB users can write simultaneously.
4. **Mobile Client Compatibility:** Official Audiobookshelf mobile apps fail if wrapped in reverse-proxy forward-auth redirects. The endpoint requires direct native authentication at the Caddy proxy level.

#### Action
1. **Turnkey Deployment Pipeline (`11-deploy-audiobookshelf.sh`):**
   * Pre-provisioned Btrfs storage directories on the Proxmox host at `/mnt/data/@simba/Media/Audiobooks` and `/mnt/data/@simba/Media/Podcasts` with `0777` permissions owned by `bjm:bjm` (`1000:1000`).
   * Created application state directories on the SSD root at `/opt/stacks/audiobookshelf/config` and `/opt/stacks/audiobookshelf/metadata`.
2. **Container Stack Provisioning:**
   * Deployed `ghcr.io/advplyr/audiobookshelf:latest` in `/opt/stacks/audiobookshelf/compose.yaml` on host port `13378:80`.
   * Attached the container to internal bridge `gateway_net` for isolated proxy communication.
   * Bind-mounted `/mnt/simba/Media/Audiobooks` to `/audiobooks` and `/mnt/simba/Media/Podcasts` to `/podcasts`.
3. **Reverse Proxy & Domain Routing:**
   * Added Caddy site blocks for `audiobooks.dixon.home` and `audiobooks.192.168.68.175.nip.io` using automated internal TLS and native reverse proxy to `audiobookshelf:80`.
   * Leveraged AdGuard Home's wildcard rewrite `*.dixon.home` $\rightarrow$ `192.168.68.175` for instant local resolution.
4. **Validation:**
   * Validated database initialization (`absdatabase.sqlite`), SQLite extensions, and HTTP 200 responses via Caddy edge proxy.

#### Consequences
* **Positive:** Complete, self-hosted audiobook and podcast streaming server active with multi-device listening progress sync.
* **Positive:** Seamless Windows desktop management: audiobooks and podcasts can be dropped directly into `M:\Audiobooks` and `M:\Podcasts`.
* **Positive:** Official iOS and Android mobile apps can connect directly via `https://audiobooks.dixon.home` without proxy redirect issues.
* **Positive:** High performance achieved by isolating high-write SQLite databases on SSD while keeping bulk audio on Btrfs RAID1.
* **Operational:** Verified client playback, browser downloading, and offline downloading via third-party mobile clients (e.g. Absorb) over direct LAN.

# ADR-0021: Immich Photo Management Stack Provisioning, External Library Mounting & GitOps Skill Codification

* **Status:** Accepted
* **Date:** 2026-10-05
* **Component:** Networking / VPN
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Multi-User Family Photo Strategy:** The operator required an autonomous, private, self-hosted photo management system operating in parallel with Google Photos. The solution needed to support seamless background camera roll uploads for multiple family members, private individual timelines, shared family albums, and partner sharing without cloud subscription costs.
2. **Zero-Copy Ingestion of Google Drive Archives:** A 116 GB archive (34,902 photos) freshly synced from Google Drive resided on the Btrfs storage pool (`/mnt/simba/Shared-All-Family/Photos/GoogleDrive`). The photo platform needed to index, face-tag, and search these archives without duplicating, moving, or modifying existing files on disk.
3. **Operational Discipline & Governance:** Changes to Docker Compose stacks, edge proxy rules, and dashboard configs on LXC 920 must follow strict GitOps discipline (authoring in `homelab-stacks`, pushing to GitHub, pulling on host, decoupling secrets). This workflow required permanent codification into Antigravity skills and rules.

## Action
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

## Consequences
* **Positive:** Complete self-hosted Google Photos alternative operational with facial recognition, map view, AI search, and background mobile uploads.
* **Positive:** Historical 116 GB photo archive indexed via read-only external mount without file movement or disk duplication.
* **Positive:** Immich database and mobile uploads are automatically protected under daily Backrest snapshot plans (`stacks_and_databases` at 03:00 AM and `family_photos` at 04:00 AM).
* **Governance:** The homelab GitOps workflow is permanently embedded as a first-class skill across all future Antigravity sessions.

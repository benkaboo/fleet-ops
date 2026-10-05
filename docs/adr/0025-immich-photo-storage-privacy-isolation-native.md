# ADR-0025: Immich Photo Storage Privacy Isolation & Native Batch Ingestion via immich-go

* **Status:** Accepted
* **Date:** 2026-10-05
* **Component:** Hardware / GPU
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **External Library Architecture Flaws:** Historical photos (116 GB / 34,902 assets) were initially mounted as a read-only external library (`/mnt/media/GoogleDrive:ro`). In Immich, external libraries are strictly read-only, preventing users from deleting photos, managing albums natively, or organizing archives from web or mobile apps. This created a fractured "split-brain" where newly uploaded camera roll items lived in native storage while historical photos remained immutable.
2. **Samba Family Share Privacy Leak:** The initial upload location (`/mnt/simba/Shared-All-Family/Photos/Immich/Uploads`) resided directly inside the Samba family share (`[Shared-All-Family]`). This inadvertently exposed raw photo files and user folders to anyone browsing network shares from Windows Explorer without authentication.
3. **Ingestion Performance & Resilience:** Ingesting 116 GB of images and videos required automated deduplication, metadata parsing, background job throttling, and fault-tolerant error handling across network interruptions.

## Action
1. **Storage Isolation & SMB Separation:**
   * Removed the temporary read-only external library from Immich.
   * Relocated Immich upload storage from `/mnt/simba/Shared-All-Family/Photos/Immich` to `/mnt/simba/Immich/Uploads` on `rath15nas`, isolating photo files completely outside Samba network shares.
   * Updated `UPLOAD_LOCATION=/mnt/simba/Immich/Uploads` in `/opt/stacks/immich/.env` on LXC 920.
2. **GitOps Repository Synchronization (`benkaboo/homelab-stacks`):**
   * Updated `immich/.env.example` to reflect the isolated `/mnt/simba/Immich/Uploads` path (`9ff1587`).
   * Removed obsolete external library volume mount (`/mnt/media/GoogleDrive:ro`) from `immich/compose.yaml` (`16bd0dd`).
   * Pulled GitOps changes on LXC 920 and restarted the Immich stack.
3. **High-Throughput Local Ingestion via `immich-go`:**
   * Installed `immich-go` (v0.32.0) on LXC 920.
   * Generated dedicated full-access Immich API key.
   * Authored automated batch ingestion runner (`/home/bjm/immich-import.sh`) executed inside a detached `tmux` session (`immich-import`) targeting `http://127.0.0.1:2283`.
   * Configured `--on-errors=continue` to gracefully bypass corrupted or non-standard legacy files and ensure uninterrupted batch completion.
   * Configured automatic pausing of background transcoding and machine learning jobs during bulk upload to dedicate full I/O throughput to the SSD bus (~45 MB/s).

## Consequences
* **Positive:** Photo management is 100% unified under native Immich date organization (`YYYY/MM`); full read, write, album management, and deletion unlocked across all clients.
* **Positive:** Complete network privacy: family members access photos exclusively through authenticated Immich clients; raw files are inaccessible via SMB.
* **Positive:** Zero risk to original source files; source archive at `/mnt/simba/Shared-All-Family/Photos/GoogleDrive` remains intact until verified.
* **Positive:** Background machine learning and transcoding automatically resume upon upload completion for GPU-accelerated facial recognition and search embeddings.

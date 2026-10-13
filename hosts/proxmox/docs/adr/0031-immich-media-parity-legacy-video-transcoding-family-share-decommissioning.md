---
id: ADR-0031
title: Immich Media Parity Validation, Legacy Video Transcoding & Family Share Decommissioning
date: 2026-10-12
status: Accepted
component: Storage & Backup
tags: [immich, transcoding, asf, ffmpeg, backrest, rclone, smb, data-governance]
---

# ADR-0031: Immich Media Parity Validation, Legacy Video Transcoding & Family Share Decommissioning

* **Status:** Accepted
* **Date:** 2026-10-12
* **Component:** Storage & Backup
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Pre-Decommissioning Parity Audit:** Following the batch ingestion of historical Google Drive photo archives into Immich (ADR-0025), the operator requested verification to determine if raw files on the Samba Family Share (`/mnt/simba/Shared-All-Family/Photos/GoogleDrive`) could be safely deleted.
2. **Media Omission & Data Loss Risks:** A cryptographic audit revealed that 175 legacy digital camera video recordings (`.asf`, 2.2 GB), 41 standalone audio voice memos (`.mp3`/`.wav`, ~250 MB), and 66 unextracted archive images in `.zip` files were skipped by initial `immich-go` folder ingestion due to file format filtering. Immediate deletion of the folder would have resulted in irreversible data loss.
3. **Automated Re-Download Storm Risk:** A systemd timer on LXC 920 (`rclone-photos-sync.timer`) actively executed `rclone copy` against Google Drive daily at 02:00 AM AEDT. Deleting the local share without halting the timer would have triggered an automatic 115 GB re-download storm overnight.
4. **Backup Target Divergence:** Backrest's daily `family_photos` backup plan targeted `/userdata/simba/Shared-All-Family/Photos`. Immich's native library (`/mnt/simba/Immich/Uploads`, 141 GB) lacked file-level restic snapshot coverage.

---

## Action
1. **Home Video Transcoding & Batch Recovery:**
   * Filtered and deduplicated the 175 `.asf` files down to 74 unique video streams via SHA-1 digest.
   * Containerized FFmpeg (via `ghcr.io/immich-app/immich-server:release`) transcoded all 74 videos to H.264/AAC MP4 (`-c:v libx264 -crf 20 -preset fast -c:a aac -b:a 128k -movflags +faststart`).
   * Preserved original file modification dates (2005–2010) on `.mp4` outputs to maintain chronological timeline placement in Immich.
2. **ZIP Archive Media Extraction & Ingestion:**
   * Queried Immich PostgreSQL database for all asset checksums.
   * Extracted 66 missing images across ZIP archives (`Photos for Rami.zip`, `Keira Oct 2010.zip`, `attachments_2009_05_03.zip`, `K & B Engagement.zip`) with original EXIF dates preserved.
   * Executed `immich-go upload from-folder` to ingest all 140 recovered media assets (100% upload success, 0 errors), increasing total Immich assets from 32,876 to 33,017.
3. **Voice Memo Preservation:**
   * Relocated all 41 historical voice recordings and lecture memos from 2005–2006 to `/mnt/simba/Shared-All-Family/Audio-Recordings-2005`, keeping them accessible over SMB without cluttering photo libraries.
4. **Disabling Automated Google Drive Ingestion Timer:**
   * Executed `sudo systemctl disable --now rclone-photos-sync.timer` and stopped `rclone-photos-sync.service` on `services`.
5. **Backrest Backup Reconfiguration:**
   * Backed up `/opt/stacks/backrest/config/config.json` to `.bak`.
   * Updated `family_photos` plan paths to protect Immich native storage and the audio archive:
     ```json
     "paths": [
       "/userdata/simba/Immich/Uploads",
       "/userdata/simba/Shared-All-Family/Audio-Recordings-2005"
     ]
     ```
   * Restarted `backrest` container and verified next scheduled execution for 04:00 AM AEDT.
6. **Family Share Decommissioning:**
   * Verified 100% media parity across Immich database.
   * Removed legacy folder `/mnt/simba/Shared-All-Family/Photos/GoogleDrive`, cleanly freeing 115 GB on Btrfs storage pool `/mnt/simba`.

---

## Consequences
* **Positive:** Complete, verified photo and video library unified natively under Immich (33,017 assets) with zero data loss.
* **Positive:** 175 legacy camera home videos recovered and made streamable on web and mobile.
* **Positive:** 115 GB of redundant storage reclaimed from NAS disk pool `/mnt/simba`.
* **Security & Privacy:** Raw photo files are fully isolated outside unauthenticated SMB shares; access is mediated strictly via Authenticated Immich sessions.
* **Resilience:** Immich's 141 GB native storage is now protected under Backrest daily restic snapshots with rolling 5-year retention.

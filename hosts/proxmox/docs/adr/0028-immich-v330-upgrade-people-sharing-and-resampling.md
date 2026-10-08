---
id: ADR-0028
title: Immich v3.3.0 Release Upgrade, Ephemeral Storage Pruning & CUDA ML Model Optimization
date: 2026-10-08
status: Accepted
component: Applications & Media
tags: [immich, v3-3-0, docker, upgrade, cuda, overlayfs, gitops]
---

# ADR-0028: Immich v3.3.0 Release Upgrade, Ephemeral Storage Pruning & CUDA ML Model Optimization

* **Status:** Accepted
* **Date:** 2026-10-08
* **Component:** Applications & Media
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Upstream Release v3.3.0:** On 2026-10-07, Immich published `v3.3.0` introducing shared people management across cluster groups, birthday celebratory memories, auto-stacked mobile edits, dynamic OAuth claims synchronization on login, and linear-light image resampling for higher detail thumbnail generation.
2. **Current Baseline State:** Immich on LXC 920 (`services`: `192.168.68.175`) was running `v3.2.4` (`immich-server:release` and `immich-machine-learning:release-cuda`). The service log registered upstream release detection notifications.
3. **Storage Boundary on LXC 920:** The root volume `/dev/mapper/pve-vm--920--disk--0` (32 GB) had 4.4 GB available. The machine learning CUDA image uncompressed size is ~7.25 GB. Attempting simultaneous parallel image pulling across server and machine learning containers triggered an overlayfs disk saturation error (`write ... libtensorrt_rtx.so: no space left on device`).
4. **Safety & Zero Data Loss Mandate:** In compliance with Tier 3 governance, a complete pre-upgrade PostgreSQL database dump was required before running any database migrations.

---

## Action
1. **Pre-Upgrade Database Backup:**
   * Dumped the entire PostgreSQL 14 database cluster from `immich_postgres` to compressed archive on `/mnt/simba/Immich/backups/immich_backup_pre_v3.3.0.sql.gz` (186 MB compressed, uncorrupted).
2. **Storage Optimization & Staged Image Extraction:**
   * Pruned unused dangling images and removed legacy CPU ML images (`immich-machine-learning:release`).
   * Staged the upgrade sequentially: pulled and recreated `immich-server` first, followed by pruning the legacy server image (`d317916b2809`), reclaiming 2.48 GB.
   * Evicted legacy ML image `b9fdebfe7f07`, expanding root disk availability to 13 GB (58% use) before pulling and extracting `ghcr.io/immich-app/immich-machine-learning:release-cuda`.
3. **Database Migration & Container Re-instantiation:**
   * Recreated containers via Docker Compose:
     * `immich-server`: Recreated with image digest `sha256:be56bc12c17a84617a979ad1eab1d9105bbec1955ffa7da09b3f9cf79d3bd09d`.
     * `immich-machine-learning`: Recreated with image digest `sha256:72c6276bd96505b8cf543bbb3dc58da9fd0654fe361ba4140dca8407e3a2be71`.
   * Immich database migrations executed cleanly on startup:
     * `ConvertUserOAuthIdEmptyStringToNull`
     * `RenameGeoNamesCountries`
     * `PersonSharing`
     * `AddPersonUserTableSharedBySharedWithConstraint`
     * No schema drift detected.
4. **Validation & Telemetry:**
   * API endpoint validation: `curl -s http://localhost:2283/api/server/version` returns `{"major":3,"minor":3,"patch":0,"prerelease":null}`.
   * Container health status: All four containers (`immich_server`, `immich_machine_learning`, `immich_postgres`, `immich_redis`) reported `healthy`.
   * GPU access verified via `nvidia-smi` inside LXC 920 matching driver `580.178.04` and CUDA 13.0.
   * Final disk headroom: 5.5 GB free on root disk `/`.

---

## Consequences
* **Positive:** Unlocked new Immich v3.3.0 capabilities (People sharing, Birthday memories, Auto-stacked edits, Linear-light thumbnail quality, Authelia OIDC claims synchronization).
* **Positive:** Preserved zero data loss with verified pre-upgrade SQL dump at `/mnt/simba/Immich/backups/immich_backup_pre_v3.3.0.sql.gz`.
* **Positive:** Retained full Pascal GPU CUDA hardware acceleration on NVIDIA GeForce GTX 1080 Ti for ML inference.
* **Operational:** Confirmed that future multi-gigabyte CUDA ML container upgrades on LXC 920 require sequential container eviction rather than simultaneous parallel pulling due to the 32 GB root disk boundary.

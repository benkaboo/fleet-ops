# Changelog

All notable changes to this project are documented in this file.

The project utilizes an atomic **Architectural Decision Record (ADR)** architecture.
For the complete historical record of architectural decisions, see the [ADR Index](docs/adr/README.md).

---

## [2026-10-08]

### [ADR-0028: Immich v3.3.0 Release Upgrade, Ephemeral Storage Pruning & CUDA ML Model Optimization](docs/adr/0028-immich-v330-upgrade-people-sharing-and-resampling.md)
* **Component:** Applications & Media
* **Summary:** Upgraded Immich to v3.3.0 across server and CUDA ML containers; resolved LXC 920 32 GB disk boundary via staged container eviction and pruning; executed pre-upgrade PostgreSQL database dump.

## [2026-10-06]

### [ADR-0027: Linux Standard Watchdog Daemon Provisioning & Immich Workload Regulation](docs/adr/0027-linux-standard-watchdog-daemon-and-immich-workload-regulation.md)
* **Component:** Networking / System Resilience
* **Summary:** Deployed Debian standard `watchdog` daemon on `rath15nas` to monitor gateway ping and `nic0`, pairing it with `/usr/local/bin/nic0-repair.sh` to auto-recover Intel I217-V DMA ring hangs in software; applied CPU and memory limits to Immich services in `compose.yaml`.

### [ADR-0026: LXC 920 Memory Scaling & Physical Bridge Link Carrier Recovery](docs/adr/0026-lxc-services-ram-scaling-physical-link-recovery.md)
* **Component:** Hardware / GPU
* **Summary:** Tripled LXC 920 memory to 12 GB RAM / 2 GB swap to absorb parallel Immich batch ingestion and CUDA ML workloads; resolved physical switch carrier stall and re-enslaved orphaned virtual interfaces to `vmbr0`.

## [2026-10-05]

### [ADR-0025: Immich Photo Storage Privacy Isolation & Native Batch Ingestion](docs/adr/0025-immich-photo-storage-privacy-isolation-immich-go.md)
* **Component:** Media & Applications
* **Summary:** Relocated Immich storage out of SMB share to `/mnt/simba/Immich/Uploads`; executed high-throughput ingestion via `immich-go` in detached tmux session.

### [ADR-0024: Pascal GPU LXC Passthrough, Docker Container Toolkit & Workload Acceleration](docs/adr/0024-pascal-gpu-lxc-passthrough-docker-container.md)
* **Component:** Hardware / GPU
* **Summary:** Configured cgroup2 passthrough and NVIDIA Container Toolkit in LXC 920; enabled hardware acceleration for Jellyfin (NVENC) and Immich ML (CUDA).

### [ADR-0023: NVIDIA GeForce GTX 1080 Ti Production Driver Deployment & Kernel 6.17 Stabilization](docs/adr/0023-nvidia-geforce-gtx-1080-ti-production.md)
* **Component:** Hardware / GPU
* **Summary:** Standardized on NVIDIA production driver branch 580 (`580.178.04-1`) with APT pinning; fixed DRM compilation on Linux 6.17 kernel and resolved boot networking deadlock.

### [ADR-0022: Authelia OIDC Single Sign-On Federation for Immich](docs/adr/0022-authelia-oidc-single-sign-on-federation.md)
* **Component:** Security & Identity
* **Summary:** Integrated Immich with Authelia OIDC provider; established internal PKI trust for secure in-cluster TLS callbacks.

### [ADR-0021: Immich Photo Management Stack Provisioning & GitOps Codification](docs/adr/0021-immich-photo-management-stack-provisioning-external.md)
* **Component:** Media & Applications
* **Summary:** Provisioned Immich stack under `/opt/stacks/immich` via GitOps; decoupled secrets and verified container health.

---

> **Historical Archive:**
> All prior decisions (ADR-0001 through ADR-0020 spanning 2026-09-06 to 2026-10-04) have been modularized into discrete files.
> Browse the full collection in the **[ADR Index](docs/adr/README.md)**.

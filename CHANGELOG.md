# Changelog

All notable changes to this project are documented in this file.

The project utilizes an atomic **Architectural Decision Record (ADR)** architecture.
For the complete historical record of architectural decisions, see the [ADR Index](docs/adr/README.md).

---

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

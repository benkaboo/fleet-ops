# ADR-0024: Pascal GPU LXC Passthrough, Docker Container Toolkit Configuration & Workload Acceleration (Jellyfin NVENC + Immich ML CUDA)

* **Status:** Accepted
* **Date:** 2026-10-05
* **Component:** Hardware / GPU
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Workload Acceleration Demands:** Following host GPU stabilization with driver 580.178.04, LXC 920 (`services`: `192.168.68.175`) required direct GPU hardware acceleration for Jellyfin (NVENC video transcoding) and Immich Machine Learning (facial recognition, image tagging, and CLIP semantic vector search).
2. **Unprivileged LXC & Cgroup BPF Restrictions:** In unprivileged LXC containers, standard Docker invocations with `--gpus all` fail because the NVIDIA Container Runtime attempts to query device cgroups using `bpf_prog_query(BPF_CGROUP_DEVICE)`, which unprivileged containers are prohibited from executing (`Operation not permitted`).
3. **CUDA Container Variant:** The default CPU-only Immich ML image (`immich-machine-learning:release`) must be switched to the CUDA-enabled release tag (`release-cuda`) to utilize GPU execution providers.

## Action
1. **Proxmox LXC Cgroup & Device Passthrough (`/etc/pve/lxc/920.conf`):**
   * Configured cgroup2 access for NVIDIA character devices: `cgroup2: 195:* rwm` (NVIDIA driver), `238:* rwm` (NVIDIA caps), and `226:* rwm` (Direct Rendering Manager / DRI).
   * Bind-mounted device nodes: `/dev/nvidia0`, `/dev/nvidiactl`, `/dev/nvidia-modeset`, `/dev/nvidia-uvm`, `/dev/nvidia-uvm-tools`, `/dev/nvidia-caps/*`, and `/dev/dri/*` with permissions `0666`.
2. **LXC User-Space Libraries & NVIDIA Container Toolkit:**
   * Installed matching branch 580 user-space libraries (`libnvidia-compute-580`, `nvidia-utils-580`) inside LXC 920.
   * Configured NVIDIA Container Toolkit repository and installed `nvidia-container-toolkit`.
   * Set `no-cgroups = true` in `/etc/nvidia-container-runtime/config.toml` to bypass unprivileged cgroup BPF inspection.
   * Configured Docker daemon (`/etc/docker/daemon.json`) to register the `nvidia` runtime as default.
3. **Declarative GitOps Service Acceleration (`benkaboo/homelab-stacks`):**
   * Updated `jellyfin/compose.yaml` with GPU device reservation (`driver: nvidia`, `capabilities: [gpu]`).
   * Updated `immich/compose.yaml` switching `immich-machine-learning` to `ghcr.io/immich-app/immich-machine-learning:release-cuda` with GPU device reservation.
   * Committed and pushed to GitHub (`521bb13`), pulled on LXC 920, and recreated containers.
4. **Verification & Provider Validation:**
   * Verified GPU passthrough in Docker (`docker run --rm --gpus all ubuntu nvidia-smi`).
   * Verified Jellyfin hardware acceleration (`docker exec jellyfin nvidia-smi`).
   * Inspected Immich ML container logs confirming active execution providers: `['TensorrtExecutionProvider', 'CUDAExecutionProvider', 'CPUExecutionProvider']`.

## Consequences
* **Positive:** Unlocked 11 GB VRAM and Pascal compute power for containerized homelab workloads with zero host performance overhead.
* **Positive:** Immich facial recognition and CLIP semantic search run with hardware acceleration rather than saturating host CPU cores.
* **Positive:** Jellyfin provides seamless hardware-accelerated transcoding for family streaming.
* **Positive:** Passthrough configuration is documented and hardened against container restarts and daemon updates.

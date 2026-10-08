---
id: ADR-0029
title: GPU-Accelerated Wyoming Whisper Speech-to-Text Deployment for Home Assistant
date: 2026-10-08
status: Accepted
component: Hardware & Acceleration
tags: [wyoming, faster-whisper, cuda, gtx-1080-ti, home-assistant, haos, voice, gitops]
---

# ADR-0029: GPU-Accelerated Wyoming Whisper Speech-to-Text Deployment for Home Assistant

* **Status:** Accepted
* **Date:** 2026-10-08
* **Component:** Hardware & Acceleration
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Local Voice Processing Demand:** To enable fast, offline, and privacy-preserving voice commands in Home Assistant (VM 940: `haos`), local Speech-to-Text (STT) inference is required.
2. **Virtual Machine GPU Constraints:** Home Assistant OS is provisioned as a KVM virtual machine (`VM 940`). The host's physical NVIDIA GeForce GTX 1080 Ti (11 GB VRAM) is managed by the Proxmox host kernel (`580.178.04`) and shared into LXC 920 (`services`) for Jellyfin (NVENC) and Immich (CUDA). Direct PCIe VFIO passthrough to VM 940 would require exclusive PCIe detachment, breaking GPU acceleration across LXC 920.
3. **Decoupled Wyoming Architecture:** The Home Assistant voice pipeline natively supports the Wyoming protocol over the local network. By deploying a CUDA-accelerated `faster-whisper` container on LXC 920 (`192.168.68.175`), Home Assistant can offload speech transcription directly to the 1080 Ti with sub-300ms latency without requiring the GPU to reside inside the VM.

## Action
1. **Network Topology Realignment:**
   * Resolved IP drift for VM 940 from dynamic DHCP `.226` to canonical infrastructure static IP `192.168.68.170/24` (Gateway: `192.168.68.1`), restoring Caddy reverse-proxy ingress at `https://ha.dixon.home`.
2. **GitOps Stack Provisioning (`homelab-stacks`):**
   * Authored `wyoming-whisper/compose.yaml` using `lscr.io/linuxserver/faster-whisper:gpu`.
   * Configured Docker GPU device reservations (`driver: nvidia`, `capabilities: [gpu]`).
   * Addressed Pascal architecture (GTX 1080 Ti) lack of native half-precision FP16 compute by explicitly configuring `WYO_WHISPER_COMPUTE_TYPE=int8_float32` (INT8 quantized weights with FP32 CUDA accumulation).
   * Configured model parameter `WHISPER_MODEL=small.en` and language `en` in `.env.example`.
   * Bound TCP port `10300` on LXC 920 (`192.168.68.175:10300`).
   * Updated `.gitignore`, `README.md`, and `homepage/config/services.yaml` with Home Assistant and Wyoming Whisper service tiles.
3. **Hypervisor Infrastructure Scaling & IaC Hardening:**
   * Scaled LXC 920 rootfs allocation from 32 GB to 64 GB via Proxmox online volume expansion (`pct resize 920 rootfs 64G`) to accommodate concurrent GPU container layers (Immich ML, Whisper GPU, Jellyfin) and cached HuggingFace model weights.
   * Updated cold-start disaster-recovery script [`scripts/lxc-setup/01-create-lxc.sh`](scripts/lxc-setup/01-create-lxc.sh) with baseline `DISK_SIZE="64"` and `RAM="12288"`.
   * Authored host mutator [`scripts/scale-lxc-disk.sh`](scripts/scale-lxc-disk.sh) and orchestrator [`scripts/deploy-scale-lxc-disk.ps1`](scripts/deploy-scale-lxc-disk.ps1).
   * Updated [`ARCHITECTURE.md`](ARCHITECTURE.md) Section 4.1 inventory with the 64 GB allocation.
4. **Container Deployment on LXC 920:**
   * Pulled upstream commits to `/opt/stacks`.
   * Hydrated `.env` and initialized persistent state directory `/opt/stacks/wyoming-whisper/data`.
   * Launched container stack via `docker compose up -d`.
   * Restarted `homepage` container to register new dashboard tiles.

## Consequences
* **Positive:** Unlocks near-instantaneous (<300ms) local voice transcription for Home Assistant powered by 11 GB VRAM and Pascal CUDA cores.
* **Positive:** Eliminates container disk starvation by permanently providing 64 GB virtual capacity backed by `local-lvm` thin provisioning.
* **Positive:** Preserves concurrent GPU sharing on LXC 920 for Immich and Jellyfin without resource starvation.
* **Positive:** Home Assistant OS VM remains lightweight with no complex NVIDIA kernel DKMS maintenance or PCIe passthrough fragility.
* **Operational:** Home Assistant connects via the native Wyoming Integration targeting `192.168.68.175:10300`.

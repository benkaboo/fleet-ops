# ADR-0023: NVIDIA GeForce GTX 1080 Ti Production Driver Deployment & Proxmox Kernel 6.17 DRM Stabilization

* **Status:** Accepted
* **Date:** 2026-10-05
* **Component:** Hardware / GPU
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Hardware Acceleration Requirement:** Containerized services on LXC 920 (specifically Immich Machine Learning for facial recognition/CLIP embeddings and Jellyfin for NVENC transcoding) required unlocking the host's dedicated NVIDIA GeForce GTX 1080 Ti (11 GB VRAM, GP102 architecture).
2. **Kernel 6.17 DRM API Incompatibility:** Upstream Debian 13 (Trixie) default packages (`nvidia-kernel-dkms` 550.163.01) failed DKMS compilation against the running Linux `6.17.2-1-pve` kernel due to breaking DRM function signature changes (`drm_helper_mode_fill_fb_struct` 4-argument signature).
3. **Open-Kernel Module Incompatibility on Pascal:** When switching to the official NVIDIA CUDA repository, unpinned dependency resolution defaulted to branch 615 open-source kernel modules (`nvidia-kernel-open-dkms`). However, NVIDIA open-kernel modules strictly require an on-die GPU System Processor (GSP) only available on Turing and newer architectures. Attempting to probe this incompatible module caused kernel hangs during boot, resulting in `udevadm settle` and `ifupdown2-pre.service` timing out and preventing `networking.service` from creating `vmbr0`.

## Action
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

## Consequences
* **Positive:** GeForce GTX 1080 Ti is fully initialized, stable, and ready for LXC cgroup device passthrough.
* **Positive:** Clean, reliable boot sequence restored; `ifupdown2-pre.service` and `networking.service` initialize in milliseconds with zero timeouts.
* **Positive:** APT repository pinned against future regressions; host system upgrades will not pull broken open-kernel drivers.
* **Operational:** Staged setup scripts (`01-host-nvidia-setup.sh`) maintained in repository for auditability and future hypervisor rebuilds.

# ADR-0027: Linux Standard Watchdog Daemon Provisioning & Immich Workload Regulation

* **Status:** Accepted
* **Date:** 2026-10-06
* **Component:** Networking / System Resilience
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Intel I217-V Hardware Unit Hang:** During heavy multi-container burst traffic (116 GB / 35,000 photo ingestion via `immich-go`, unthrottled BullMQ GPU ML workers, and scheduled HTPC Restic backups), the onboard Intel Ethernet Connection I217-V (`PCI_ID=8086:153B`, driver `e1000e`) on `rath15nas` experienced an unrecoverable silicon DMA ring deadlock, dropping 315,209 packets at the ring buffer and causing full Layer 2 network loss across the hypervisor and all guest containers.
2. **Uptime & State Verification:** Host inspection confirmed 15.5 hours of continuous uptime with no kernel panic, OOM crash, or reboot; the failure was isolated strictly to the physical NIC DMA controller. Re-seating the Ethernet cable or power-cycling the physical link reset the controller and restored connectivity.
3. **Workload Regulation Necessity:** Immich services (`immich-server` and `immich-machine-learning`) had no CPU quotas or memory bounds declared in `compose.yaml`, permitting background BullMQ indexing workers to overwhelm host network socket queues.
4. **Architectural Path & Future Router Integration:** Rather than disabling kernel TCP Segmentation Offload (TSO/GSO) statically, the operator selected a dual-pronged strategy: regulating application workload concurrency and deploying the standard Linux POSIX `watchdog` daemon on `rath15nas` with self-healing link reset capabilities. In addition, an upcoming router upgrade (GL.iNet Flint 2 GL-MT6000 running OpenWrt with 1 GB RAM) was identified as a future platform for out-of-band monitoring and external alerting.

## Action
1. **Application-Layer Workload Regulation:**
   * Updated [`Projects/homelab-stacks/immich/compose.yaml`](../../../../homelab-stacks/immich/compose.yaml) to declare CPU and memory limits:
     * `immich-server`: Capped at `cpus: '2.5'`, `memory: 4096M`.
     * `immich-machine-learning`: Capped at `cpus: '2.0'`, `memory: 4096M` while retaining dedicated NVIDIA GTX 1080 Ti GPU reservations.
   * Documented in-app tuning in Immich Web Admin (**Administration > Settings > Job Settings**) to clamp worker concurrency to 1 per AI queue.
2. **POSIX/Linux Watchdog Daemon Provisioning:**
   * Authored [`scripts/setup-network-watchdog.sh`](../scripts/setup-network-watchdog.sh) and [`scripts/deploy-network-watchdog.ps1`](../scripts/deploy-network-watchdog.ps1).
   * Configured `/etc/watchdog.conf` with declarative checks: `interface = nic0`, `ping = 192.168.68.1`, `ping-count = 3`, `interval = 15`.
   * Authored self-healing repair binary `/usr/local/bin/nic0-repair.sh` to execute a software link reset (`ip link set dev nic0 down && sleep 2 && ip link set dev nic0 up`) upon 3 consecutive probe failures.
3. **Incident Documentation:**
   * Formally registered incident `INC-20261006-01` in [`hosts/proxmox/INCIDENTS.md`](../INCIDENTS.md).

## Consequences
* **Positive:** Sub-minute, automated self-healing without requiring physical human cable re-seats if an `e1000e` DMA ring stall recurs.
* **Positive:** Workload bursts are capped at the container runtime level, protecting host CPU and network queues from saturation.
* **Positive:** Retains stock Linux kernel TSO/GSO defaults and vanilla network drivers.
* **Operational:** Future migration of out-of-band alerting, DNS (AdGuard Home), and WireGuard offload to the upcoming GL.iNet Flint 2 router will decouple infrastructure health monitoring from server uptime entirely.

# ADR-0026: LXC 920 Memory Scaling (12 GB) & Physical Bridge Link Carrier Recovery

* **Status:** Accepted
* **Date:** 2026-10-05
* **Component:** Hardware / GPU
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Container Memory Exhaustion & OOM Lockup:** Bulk photo ingestion (116 GB / 34,902 assets via `immich-go`) concurrently executing with GPU-accelerated machine learning (CUDA facial recognition and CLIP semantic embeddings on the GTX 1080 Ti) pushed memory utilization in LXC 920 (`services`) beyond its provisioned 4,096 MB RAM and 1,024 MB swap envelope. This induced an out-of-memory kernel lockup.
2. **Physical Switch Port Carrier Stall:** Following host hard-lock and recovery attempts, the upstream physical Deco mesh switch port entered a hung state, presenting electrical carrier (`Link detected: yes`) while failing to forward Layer 2 broadcast/unicast traffic (`tcpdump -i nic0` captured zero frames).
3. **Bridge Port Orphanage:** Manual recreation of host bridge `vmbr0` while guest containers were running orphaned virtual interface endpoints (`veth920i0`, `tap940i0`), dropping internal DNS (`192.168.68.175`) and causing client requests to `photos.dixon.home` to fail with `NXDOMAIN`.

## Action
1. **Physical Link Restoration:**
   * Diagnosed zero packet transmission on `nic0` via packet capture.
   * Power-cycled the physical link via cable reseat; confirmed immediate packet arrival and Layer 2 ARP resolution.
2. **Container Memory Scaling:**
   * Scaled LXC 920 memory from 4,096 MB to 12,288 MB (12 GB) and expanded swap to 2,048 MB (`pct set 920 -memory 12288 -swap 2048`).
   * Authored automated staging runner [`scripts/restart-and-scale-lxc.sh`](../../scripts/restart-and-scale-lxc.sh) to execute reconfiguration.
3. **Bridge Enslavement & Service Recovery:**
   * Restarted LXC 920 (`services`), LXC 930 (`agcode`), and rebooted VM 940 (`haos`), re-enslaving their virtual taps and veth pairs to `vmbr0`.
   * Verified bridge membership with `ip -br link show master vmbr0`.
4. **End-to-End Ingress Verification:**
   * Verified `photos.dixon.home` resolves to `192.168.68.175` via local AdGuard Home.
   * Verified `https://photos.dixon.home`, `https://home.dixon.home`, and `https://auth.dixon.home` return `HTTP 200 OK`.
   * Verified container memory telemetry: 3.1 GiB used, 8.9 GiB free, 0 B swap consumed.
5. **Documentation Synchronization:**
   * Updated [`ARCHITECTURE.md`](../../ARCHITECTURE.md) container specifications table and Section 4.1.

## Consequences
* **Positive:** LXC 920 has substantial memory headroom (12 GB) to comfortably absorb high-throughput photo batch ingestion and parallel GPU ML embeddings without OOM instability.
* **Positive:** Clean recovery of all private homelab web applications, internal DNS, and hypervisor management portals.
* **Operational:** Proxmox hypervisor maintains ~19 GB free host RAM for ZFS ARC caching, Samba exports, and HAOS VM 940 operations.

# ADR-0012: Home Assistant OS (HAOS) Virtual Machine (VM 940) Provisioning & Hybrid Smart Home Architecture

* **Status:** Accepted
* **Date:** 2026-09-20
* **Component:** Hardware / GPU
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Cloud Fragility & Offline Outage Impact:** The operator's home automation setup relied on Google Home and Google Nest devices. During intermittent internet outages, all device-to-device communication and smart home controls were severed due to Google Home's cloud-dependent architecture.
2. **Hardware Preservation & Hybrid Strategy:** Operator owns multiple Google Nest Audio, Nest Mini, and smart display devices. Replacing all hardware would be disruptive and costly. An architectural evaluation selected a hybrid topology: Home Assistant serves as the local, offline-resilient automation engine and state coordinator, while Google Nest speakers are retained as local Cast media targets and cloud voice input endpoints.
3. **Hypervisor Sizing & Isolation:** Proxmox host `rath15nas` maintains ~26 GB of available RAM. Deploying Home Assistant as an official KVM virtual machine (HAOS) rather than a Docker container in LXC 920 guarantees access to the official Supervisor, one-click Add-on Store, seamless USB passthrough for future Zigbee/Z-Wave coordinators, and isolated networking. A conservative allocation of 2 GB RAM and 2 vCPUs preserves >22 GB host memory headroom while remaining expandable on demand.

## Action
1. **Automation Scripting:**
   * Authored [`scripts/setup-haos-vm.sh`](scripts/setup-haos-vm.sh) implementing automated discovery of the latest HAOS release from GitHub, UEFI OVMF initialization, `q35` machine profile creation, disk import to `local-lvm`, and automatic volume resize to 32 GB.
   * Authored PowerShell workstation orchestrator [`scripts/deploy-haos-vm.ps1`](scripts/deploy-haos-vm.ps1) for authenticated staging and interactive `sudo` execution.
2. **Network Design:**
   * Configured primary network interface attached to `vmbr0` (Management LAN `192.168.68.0/24`).
   * Placing the VM directly in the same Layer 2 broadcast domain as Google Nest speakers enables zero-configuration mDNS and Google Cast protocol discovery without requiring multicast forwarding proxies.
3. **Ingress & Reverse Proxy Routing:**
   * Authored and executed [`scripts/configure-caddy-ha.sh`](scripts/configure-caddy-ha.sh) and [`scripts/deploy-caddy-ha.ps1`](scripts/deploy-caddy-ha.ps1) on LXC 920.
   * Configured Caddy routes for `ha.192.168.68.175.nip.io` and `ha.dixon.home` with automated TLS termination and websocket proxying to `192.168.68.170:80`.
   * Authorized proxy IP `192.168.68.175` under Home Assistant's trusted proxies.
4. **Architecture Synchronization:**
   * Updated [`ARCHITECTURE.md`](ARCHITECTURE.md) Section 4 with VM 940 specifications, Caddy reverse proxy routing, and automation scripts.

## Consequences
* **Positive:** Unlocks 100% local, offline-capable smart home automations and sensor coordination independent of ISP uptime.
* **Positive:** Retains full utility of existing Google Nest Audio/Mini devices as local media players and Text-to-Speech (TTS) notification targets.
* **Positive:** Access to full Home Assistant Supervisor and Add-on ecosystem (Mosquitto MQTT, Zigbee2MQTT, ESPHome).
* **Operational:** Minimal host resource consumption (~2 GB RAM, 2 vCPUs), leaving >22 GB RAM free for LXC 920 and host storage caching.

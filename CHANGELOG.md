# Changelog

All notable architectural decisions, maintenance operations, and system baselines for `rath15-htpc` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [2026-09-09]

### Baseline: Initial System Discovery & Architecture Inventory

* **Discovery Execution:** Executed non-invasive remote telemetry discovery script `scripts/inspect_htpc_remote.ps1` over SSH.
* **Hardware Profile Captured:**
  * CPU: AMD Ryzen 5 5600X 6-Core / 12-Thread Processor.
  * GPU: NVIDIA GeForce RTX 3060 (Driver 32.0.15.9621) running at 4K resolution (3840x2160).
  * Motherboard: MSI MAG B550 TOMAHAWK.
  * RAM: 16 GB Total RAM (4.32 GB Free).
* **Storage Topology:**
  * 1 TB Crucial MX500 SATA SSD (`C:\` - 465 GB free / 50%).
  * 4 TB WD Red SATA HDD partitioned into `F:\` (92 GB free), `G:\` (77.9 GB free), and `H:\` (84.1 GB free).
  * Mapped Network Shares: `M:\` (`\\192.168.68.169\Media`), `N:\`, `P:\`, and `X:\` (`\\HPNAS01`).
* **Health & Stability:**
  * Confirmed 0 WHEA hardware error events.
  * Confirmed 0 Kernel-Power 41 unexpected shutdowns over the trailing 7 days.
* **Documentation Generated:** Produced authoritative architecture document [`ARCHITECTURE.md`](file:///C:/Users/benma/coding/agy_project/Projects/htpc/ARCHITECTURE.md) and full baseline report [`reports/baseline_inventory.md`](file:///C:/Users/benma/coding/agy_project/Projects/htpc/reports/baseline_inventory.md).

### ADR: Hardened OpenSSH Remote Management Channel & Ed25519 Authentication

#### Context
1. **The Problem / Requirement:** Physical administration of `rath15-htpc` in the living room requires local keyboard access. Prior Remote Desktop (RDP) login attempts failed due to local user account naming discrepancies (`benka_000` created during Microsoft Account setup). Furthermore, connecting via RDP terminates or locks the physical display, interrupting TV playback and media rendering.
2. **Constraints & Trade-offs:** Remote management must be secure, lightweight, and capable of background execution without disrupting living room display output or media streams.

#### Action
1. **Implementation Steps:**
   * Deployed Microsoft OpenSSH Server (`OpenSSH-Win64`) to `C:\Program Files\OpenSSH` on `rath15-htpc`.
   * Configured Windows Service `sshd` to start automatically on system boot.
   * Created inbound Windows Firewall rule restricting TCP port 22 strictly to `LocalSubnet` (`192.168.68.0/24`) on the `Private` network profile.
   * Deployed Ben's workstation Ed25519 public key to `C:\ProgramData\ssh\administrators_authorized_keys` with strict Windows ACL permissions (`SYSTEM` and `Administrators` only).
   * Configured workstation SSH client alias `Host rath15-htpc` pointing to `192.168.68.162` with user `benka_000`.
2. **Key Parameters:**
   * Node IP: `192.168.68.162`
   * Target Port: `22` (TCP - LocalSubnet Only)
   * Local User: `benka_000`
   * Key: Ed25519 Asymmetric Cryptography
3. **Verification & Testing:**
   * Verified port 22 open and responsive via socket probe.
   * Executed passwordless remote command `whoami & hostname` over SSH; confirmed deterministic execution without password prompts.

#### Consequences
* **Positive:** High-security, cryptographically authenticated remote administration established. Zero password transmission over the network.
* **Operational:** Remote maintenance, diagnostics, and updates can now be run completely in the background without affecting the living room TV screen or media playback.
* **Security:** Attack surface minimized by binding port 22 strictly to the local home subnet.

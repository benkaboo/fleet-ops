# ADR-0005: Enforce WSL2 Resource Sandbox via .wslconfig

* **Status:** Accepted
* **Date:** 2026-09-08
* **Component:** Security & Governance
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **The Problem / Requirement:** The workstation host runs WSL2 (`Ubuntu`), but lacks a `%USERPROFILE%\.wslconfig` boundary file. By default, WSL2 dynamically claims up to 50% of total host RAM (7.5 GB on this 16 GB machine) without aggressive memory reclamation. Since primary container and Linux development is now offloaded to the dedicated codebox, unconstrained local WSL allocation presents unnecessary host memory contention risk.
2. **Constraints & Trade-offs:** Local Linux tools must remain accessible without deleting the Ubuntu distro (7.58 GB `ext4.vhdx`). Resource ceilings must guarantee the Windows host never experiences out-of-memory pressure or page-file thrashing from dormant or minor WSL tasks.

## Action
1. **Implementation Steps:**
   * Created version-controlled configuration template at `configs/.wslconfig`.
   * Created deployment script `scripts/apply_wslconfig.ps1` and rollback script `scripts/remove_wslconfig.ps1`.
   * Applied configuration to `%USERPROFILE%\.wslconfig` setting `memory=2GB`, `processors=2`, `swap=1GB`, and `autoMemoryReclaim=dropcache`.
   * Executed `wsl --shutdown` to cleanly enforce bounds on the subsystem.
   * Updated `ARCHITECTURE.md` Section 4.2 and Section 9 (Architectural Tradeoffs table).
2. **Key Parameters:**
   * Target Path: `%USERPROFILE%\.wslconfig`
   * Memory Limit: `2GB`
   * Processor Limit: `2 vCPUs`
   * Swap Limit: `1GB`
   * Memory Reclaim Mode: `dropcache`
   * Reversal Script: `scripts/remove_wslconfig.ps1`
3. **Verification & Testing:**
   * Verified `%USERPROFILE%\.wslconfig` file contents.
   * Confirmed successful shutdown and registration with WSL2.

## Consequences
* **Positive:** Guaranteed host stability; WSL2 can never consume more than 2 GB of memory. Cached memory is proactively reclaimed and returned to Windows.
* **Operational:** Heavy multi-core container builds cannot be run locally without adjusting `.wslconfig`, which aligns with the decision to offload container workflows to the codebox.
* **Security:** Hardened host boundaries by limiting compute and memory access granted to subsystem virtual machines.

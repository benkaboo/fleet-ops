# ADR-0007: Decommissioning of Legacy ASUS Kernel Drivers (AsIO/AsUpIO) and Orphaned AI Suite Services

* **Status:** Accepted
* **Date:** 2026-09-28
* **Component:** Storage & Backup
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **The Problem / Requirement:** Following a system restart of `rath15-htpc`, a recurring Windows Security desktop toast notification warned: *"A driver cannot load on this device: AsIO.sys"*. System Event 7026 logged: *"The following boot-start or system-start driver(s) did not load: AsIO, AsUpIO, dam"* and Code Integrity Event 3077 logged that `\Windows\SysWOW64\Drivers\AsIO.sys` violated Microsoft Authenticode / Code Integrity policy.
2. **Investigation Findings:**
   * In a prior optimization session ([commit `62b9f6e`](#adr-host-optimization-virtual-memory-topology-and-autostart-streamlining)), only user-mode service `asComSvc` was disabled to resolve a 45-second boot timeout.
   * Kernel-mode driver services `AsIO` and `AsUpIO` remained configured with `Start = 1` (`SERVICE_SYSTEM_START`), forcing the Windows OS kernel to attempt loading 14-year-old 32-bit drivers (dated 2012) on every boot.
   * Windows 11 Memory Integrity (HVCI) and the Microsoft Vulnerable Driver Blocklist actively blocked `AsIO.sys` due to known privilege escalation CVEs, triggering the user warning.
   * Additional legacy ASUS background services (`asHmComSvc` and `AsSysCtrlService`) were still actively running in memory.
   * Hardware audit confirmed zero ASUS components in `rath15-htpc` (MSI MAG B550 TOMAHAWK motherboard, Gigabyte GeForce RTX 3060 GPU, AMD Ryzen 5 5600X CPU). All ASUS services and drivers were orphaned remnants of an ASUS AI Suite II installation from 2012–2015.
3. **Constraints & Trade-offs:**
   * Disabling drivers must be completely reversible via pre-flight registry backups.
   * Zero disruption to active gaming or media playback subsystems.

## Action
1. **Implementation Steps:**
   * Exported pre-flight registry backups for all target keys to `C:\ProgramData\htpc_maintenance_backups\`:
     - `AsIO_driver_backup.reg`
     - `AsUpIO_driver_backup.reg`
     - `asHmComSvc_backup.reg`
     - `AsSysCtrlService_backup.reg`
   * Disabled kernel driver services `AsIO` and `AsUpIO` by setting `Start = 4` (`SERVICE_DISABLED`) in `HKLM:\SYSTEM\CurrentControlSet\Services\AsIO` and `AsUpIO`.
   * Stopped and disabled legacy ASUS Win32 services `asHmComSvc` (`aaHMSvc.exe`) and `AsSysCtrlService` (`AsSysCtrlService.exe`).
   * Updated workstation OpenSSH config (`~/.ssh/config`) and repository specifications to reflect the current dynamic DHCP lease (`192.168.68.33`).
2. **Key Parameters:**
   * Target Driver Services: `AsIO` (`Start: 1 -> 4`), `AsUpIO` (`Start: 1 -> 4`)
   * Target Win32 Services: `asHmComSvc` (`Disabled`, `Stopped`), `AsSysCtrlService` (`Disabled`, `Stopped`)
   * Motherboard Verification: MSI MAG B550 TOMAHAWK (Vendor `Micro-Star International`)
   * GPU Verification: Gigabyte RTX 3060 (Vendor `0x1458`)
3. **Verification & Testing:**
   * Confirmed `(Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\AsIO).Start` is `4`.
   * Confirmed `(Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\AsUpIO).Start` is `4`.
   * Confirmed `Get-Service asHmComSvc, AsSysCtrlService, asComSvc` all report `Status: Stopped` and `StartType: Disabled`.
   * Verified zero active ASUS processes (`aaHMSvc`, `AsSysCtrlService`) in process memory.

## Consequences
* **Positive:** Completely stopped Windows from attempting to load blocked, vulnerable legacy drivers; eliminated the "A driver cannot load on this device: AsIO.sys" desktop toast notification and Event 3077/7026 boot errors.
* **Operational:** Decommissioned two useless background services from process memory.
* **Reversibility:** Original configurations fully preserved in `.reg` files in `C:\ProgramData\htpc_maintenance_backups\`.

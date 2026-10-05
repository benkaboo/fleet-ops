# ADR-0008: Microsoft GameInput Conflict Resolution & Service Unification

* **Status:** Accepted
* **Date:** 2026-09-09
* **Component:** Gaming & Streaming
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **The Problem / Requirement:** System logs revealed recurring `MsiInstaller` Event ID 1035 reconfiguration cycles and a sleep-state hard shutdown (`Kernel-Power` Event ID 41, `BugcheckCode 0`) occurring during Modern Standby. Inspection identified two competing GameInput services: the native Windows 11 system service (`GameInputSvc` in `System32`) and a redundant standalone MSI redistributable (`GameInputRedistService` v3.3.221.0 in `Program Files\Microsoft GameInput`).
2. **Constraints & Trade-offs:** Controller support and input APIs must remain completely operational. The native Windows 11 system service handles all GameInput APIs and renders the standalone redistributable redundant.

## Action
1. **Implementation Steps:**
   * Developed maintenance script [`scripts/uninstall_gameinput.ps1`](file:///C:/Users/benma/coding/agy_project/Projects/Workstation/scripts/uninstall_gameinput.ps1).
   * Executed silent uninstallation of standalone package `{14EDF950-06B9-415F-862C-1D5DEC321AE6}` (`Microsoft.GameInput`).
   * Purged redundant `GameInputRedistService` while retaining native Windows 11 `GameInputSvc` (`C:\WINDOWS\System32\GameInputSvc.exe`).
   * Updated `ARCHITECTURE.md` Section 9 to document the tradeoff decision.
2. **Key Parameters:**
   * Target Package: `Microsoft GameInput` (`3.3.221.0`)
   * Removed Service: `GameInputRedistService`
   * Retained Service: `GameInputSvc` (Status: Running)
3. **Verification & Testing:**
   * Executed `Get-Service *gameinput*`; confirmed only native `GameInputSvc` is present and active.
   * Executed `winget list -q GameInput`; confirmed package completely deregistered.
   * Confirmed Event ID 1034 / 11724 (successful removal) in Application Event Log.

## Consequences
* **Positive:** Completely eliminates background MSI reconfiguration loops and removes a known trigger of Modern Standby stalls and sleep-state hard resets.
* **Operational:** Peripheral and controller support continues natively via the built-in Windows 11 system service.
* **Security:** Removes unmanaged third-party binary surface in `Program Files`.

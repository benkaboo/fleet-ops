# ADR-0007: Host Python Simplification & Devbox Offloading Strategy

* **Status:** Accepted
* **Date:** 2026-09-08
* **Component:** Security & Governance
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **The Problem / Requirement:** The host workstation had dual Python installations (Python 3.12 in user AppData and Python 3.14 in system root) registered across multiple package managers (Winget and Chocolatey), alongside a conflicting Microsoft Store execution alias for `python3.exe`. Because primary application engineering, models, and container builds are offloaded to the dedicated devbox, maintaining multiple local runtimes created unnecessary version fragmentation.
2. **Constraints & Trade-offs:** The host requires a reliable, lightweight Python environment strictly for system management, local scripts, and agent tooling. Both `python` and `python3` commands must execute cleanly without opening the Microsoft Store.

## Action
1. **Implementation Steps:**
   * Executed `winget uninstall --id Python.Python.3.12 --silent` to cleanly remove the user-level Python 3.12 runtime and unregister it from Windows.
   * Created and executed `scripts/finalize_python_unification.ps1` to purge residual user `site-packages` (reclaimed 40.45 MB) and deploy `python3.cmd` shim (`@"C:\Python314\python.exe" %*`) to `%LOCALAPPDATA%\agy\bin`.
   * Updated `ARCHITECTURE.md` Section 6.1 and Section 9 (Architectural Tradeoffs table).
2. **Key Parameters:**
   * Unified Host Runtime: `Python 3.14.6` (`C:\Python314\python.exe`)
   * Removed Package: `Python.Python.3.12`
   * Shim Path: `%LOCALAPPDATA%\agy\bin\python3.cmd`
3. **Verification & Testing:**
   * Executed `py --list`; confirmed only `-V:3.14 * Python 3.14 (64-bit)` is registered.
   * Executed `python --version` -> `Python 3.14.6`.
   * Executed `python3 --version` -> `Python 3.14.6`.
   * Confirmed zero Microsoft Store popups or execution alias errors.

## Consequences
* **Positive:** Completely eliminated runtime drift and Microsoft Store alias traps. The local host workstation operates with a lean, single-version Python 3.14 installation dedicated to host automation, with zero clutter from legacy project libraries.
* **Operational:** All application development, virtual environments, and heavy libraries remain isolated on devbox.
* **Security:** Reduced attack surface and dependency vulnerabilities by purging unmanaged local Python 3.12 site-packages.

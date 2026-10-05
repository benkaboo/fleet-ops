# Workstation Host Audit & Optimization Guidelines

## Project Purpose
Conduct a safe, non-invasive system analysis of Ben's Windows development workstation, produce an authoritative architecture document (`ARCHITECTURE.md`), and execute staged, low-risk cleanups without disrupting operational stability.

## Scope & Operational Boundaries
* **Target System:** Host Windows workstation (`benma`).
* **Protected System Zones (STRICTLY PROHIBITED FROM DIRECT MUTATION):**
  - `C:\Windows\`
  - `C:\Program Files\Windows Defender` / Security center services
  - Boot configuration, pagefile, or system hibernation files
  - Active user documents in `Documents`, `Desktop`, `Pictures` (without explicit per-file confirmation)
* **Permitted Analysis Zones:**
  - Package manager caches (`npm`, `pip`, `winget`, `docker`, `cargo`)
  - User temp folders (`%TEMP%`, `C:\Windows\Temp` read-only)
  - `%LOCALAPPDATA%` and `%APPDATA%` (for leftover folders of uninstalled software)
  - Developer runtimes (Python, Node, WSL2 distributions, Docker images)

## Execution Tiers
* **Tier 1 (Autonomous):** Run read-only PowerShell commands (`Get-*`, `dir`, `wsl -l -v`, `winget list`, etc.) freely to diagnose and map the machine.
* **Tier 2 (Cache Cleanups):** State target directory and estimated size before prompting for simple confirmation.
* **Tier 3 (Mutations & Deletions):** Present the full **Pre-Flight Security Card** (Target, Operation Type, Blast Radius, Rollback Plan, Verification Test) before executing any removal, registry edit, or service alteration.

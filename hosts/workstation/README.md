# Workstation Host Architecture & Maintenance

This repository manages the system architecture baseline, diagnostic tooling, and safe optimization workflows for Ben's Windows development workstation.

## Directory Structure
* `AGENTS.md` - Workspace-specific safety boundaries and execution tiers.
* `ARCHITECTURE.md` - Authoritative workstation architecture and system specifications.
* `CHANGELOG.md` - Architectural Decision Records (ADRs) and maintenance history.
* `scripts/` - Non-invasive inspection and diagnostic automation scripts.
* `reports/` - Timestamped audit summaries and baseline inventory captures.

## Quick Start
Run the read-only host inspection script:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\inspect_host.ps1
```
The resulting baseline inventory will be saved to `reports\baseline_inventory.md`.

# rath15-htpc Host Architecture & Maintenance

This repository manages the system architecture baseline, diagnostic tooling, and safe optimization workflows for Ben's Home Theater PC (`rath15-htpc`).

## System Role & Topology
* **Node Identifier:** `rath15-htpc`
* **Network Address:** `192.168.68.162`
* **Remote Access Protocol:** OpenSSH Server (Ed25519 public-key authentication, port 22 restricted to `LocalSubnet`)
* **Underlying Storage Mount:** `S:` (`\\RATH15NAS\simba`)

## Directory Structure
* `AGENTS.md` - Operational boundaries, media protection rules, and execution tiers.
* `ARCHITECTURE.md` - Authoritative system architecture, hardware topology, and media services.
* `CHANGELOG.md` - Architectural Decision Records (ADRs) and maintenance logs.
* `scripts/` - Automated remote and local inspection and optimization scripts.
* `reports/` - Timestamped baseline inventory captures and diagnostic audits.

## Remote Administration
Connect directly from your workstation:
```powershell
ssh rath15-htpc
```

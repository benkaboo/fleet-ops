# HTPC Host Audit & Architecture Guidelines (rath15-htpc)

## Project Purpose
Maintain an authoritative, version-controlled system architecture (`ARCHITECTURE.md`), changelog (`CHANGELOG.md`), and diagnostic toolchain for the home theater PC (`rath15-htpc`), supporting non-invasive audits and remote maintenance via hardened OpenSSH without disrupting media playback or living room operational stability.

## Target Node Specifications
* **Host Identifier:** `rath15-htpc`
* **Network IP:** `192.168.68.33` (DHCP lease; Subnet: `192.168.68.0/24`)
* **Primary Access Method:** OpenSSH (`ssh rath15-htpc` / Ed25519 key-authenticated)
* **Local User Identity:** `benka_000`

## Scope & Operational Boundaries
* **Target System:** Host Windows machine (`rath15-htpc`).
* **Protected System Zones (STRICTLY PROHIBITED FROM DIRECT MUTATION):**
  - `C:\Windows\`
  - Display adapter / GPU drivers and HDMI audio output subsystems
  - Active media player databases and configurations (Kodi, Plex, Jellyfin, VLC)
  - Network share mount credentials and NAS media paths (`\\RATH15NAS\simba`)
  - Active user documents in `Documents`, `Desktop`, `Pictures`
* **Permitted Analysis & Maintenance Zones:**
  - Package manager caches and runtimes
  - User temp folders (`%TEMP%`, `C:\Windows\Temp` read-only)
  - Autostart entries and background media helper services
  - Windows Event logs (Application, System, Hardware WHEA, Diagnostics-Performance)
  - Remote management daemons (`sshd`, firewall rules)

## Execution Tiers
* **Tier 1 (Autonomous Remote Inspection):** Read-only commands executed locally or over SSH (`Get-*`, `dir`, `dism`, `netstat`, `wmic`, `tasklist`, `Get-WinEvent`). Pre-authorized for autonomous diagnostics.
* **Tier 2 (Low-Risk Ephemeral Cleanups):** State target directory, estimated space reclamation, and impact before prompting for user confirmation.
* **Tier 3 (Mutating / High-Security Operations):** Present the full **Pre-Flight Security Card** (Target, Operation Type, Blast Radius, Rollback Plan, Verification Test) before modifying any registry keys, firewall rules, service configurations, package uninstalls, or drivers.

# Changelog

All notable changes to the Federated Remote Gaming project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-09-27

### Added
- Added automated pre-flight session handoff launcher (`Start-RemoteGaming.ps1`) to arbitrate physical GPU console ownership over SSH.
- Created `Start Remote Gaming.lnk` desktop shortcut on workstation pairing pre-flight checks with Moonlight client launch.
- Updated project architecture and quick-start documentation to reflect dynamic DHCP mDNS resolution (`rath15-htpc.local`) and multi-user session management.

---

### Architectural Decision Record (ADR 002): Automated Multi-User Console Handoff

#### Context
1. **The Problem / Requirement:** In a shared living room HTPC environment, local logins at the TV by other family members (e.g. `dylan_93nze6m`) preempt the physical GPU console (`console`). This pushes the gaming user session (`benka_000`) into a disconnected state (`Disc`). Because Sunshine binds to whichever session holds the physical console, subsequent Moonlight launch requests for Playnite executed in the wrong user context, throwing Windows `ERROR_ACCESS_DENIED (5)`. Disconnect teardowns also periodically deadlocked Sunshine's HTTPS worker thread on port 47984.
2. **Constraints & Trade-offs:** Preserving the living room TV user's running processes without hard logouts, while enabling frictionless 1-click remote gaming takeover from the workstation without requiring manual SSH terminal commands or physical access to the TV.

#### Action
1. Created `Start-RemoteGaming.ps1` on the workstation using OpenSSH Ed25519 authentication to query `qwinsta` on `rath15-htpc.local`.
2. Implemented automated session arbitration: if `benka_000` is disconnected, executes `tscon <SessionId> /dest:console` over SSH to seamlessly attach the gaming session to the console.
3. Added Sunshine service health probe to automatically restart `SunshineService` if daemon threads are deadlocked.
4. Generated a desktop shortcut `Start Remote Gaming.lnk` on the workstation pointing to the automated script.
5. Synchronized documentation across `README.md` and `ARCHITECTURE.md`.

#### Consequences
* **Positive:** Completely eliminates `ERROR_ACCESS_DENIED (5)` and "Failed to start specified application (Error 0)" launch failures when switching from TV to remote workstation gaming.
* **Positive:** Background processes belonging to the local TV user remain active in their disconnected session rather than being terminated.
* **Operational:** User launches games via the "Start Remote Gaming" desktop shortcut rather than launching raw Moonlight directly.
* **Security:** Operates strictly within authenticated SSH key boundaries (`benka_000`); no credentials exposed in plain text or script arguments.

---

## [1.0.0] - 2026-09-12

### Added
- Initialized repository and system architecture documentation for federated game streaming between `LENOVO16_LP` (Workstation) and `RATH15-HTPC` (Host).
- Deployed **Moonlight Game Streaming Client v6.1.0** on Workstation (`%LOCALAPPDATA%\Programs\Moonlight`).
- Installed and registered **Sunshine Service v2026.906.222525** on `RATH15-HTPC` with NVENC hardware acceleration (HEVC / H.264 / AV1).
- Configured Sunshine `apps.json` with **Playnite Fullscreen Mode**, Desktop, and Steam Big Picture entries.
- Validated **ViGEmBus** virtual gamepad driver on HTPC for low-latency Xbox controller emulation.

---

### Architectural Decision Record (ADR 001)

#### Context
The user wanted to federate game libraries across Steam, Epic Games, GOG, and Amazon Games / Luna to play on the Workstation (`LENOVO16_LP`) streamed from the high-spec living room HTPC (`RATH15-HTPC`). The previous solution relied strictly on Steam Remote Play, which failed to cleanly handle non-Steam stores, suffered from overlay capture issues, and lacked unified game federation.

#### Action
1. Installed Moonlight Client on `LENOVO16_LP` as a portable user-space deployment.
2. Installed Sunshine as an automatic Windows system service on `RATH15-HTPC`, binding to NVENC hardware encoding on the NVIDIA RTX 3060.
3. Added Playnite Fullscreen Mode (`Playnite.FullscreenApp.exe`) as an explicit application entry in Sunshine's `apps.json`.
4. Leveraged existing ViGEmBus driver on HTPC for zero-config controller passthrough from the Workstation's Bluetooth Xbox controller.

#### Consequences
- **Positive:** Unlocks low-latency, hardware-encoded 60+ FPS streaming for all digital distribution platforms (Steam, Epic, GOG, Amazon, Luna) inside a unified 10-foot gamepad UI.
- **Positive:** No disruption to living room TV viewing; operates fully headless or concurrent with TV input switching.
- **Positive:** Significant reduction in input latency compared to Steam Remote Play.
- **Neutral:** Sunshine web management interface must be paired once with Moonlight via a 4-digit PIN.

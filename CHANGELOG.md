# Changelog

All notable changes to the Federated Remote Gaming project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

# ADR-0005: Headless In-Home Game Streaming via Steam Remote Play and Zero-LPE Console Handoff

* **Status:** Accepted
* **Date:** 2026-09-11
* **Component:** Gaming & Streaming
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **The Problem / Requirement:** High-performance, low-latency PC gaming on authorized client workstations utilizing the dedicated NVIDIA GeForce RTX 3060 graphics processor on `rath15-htpc` (`192.168.68.162`) via Steam Remote Play. The physical television connected to `rath15-htpc` is actively used for living room entertainment (Google TV on an alternate HDMI input), requiring completely non-invasive, headless session switching, user account isolation, and zero HDMI mode disruptions.
2. **Constraints & Trade-offs:**
   * **TV Display Independence:** Windows session handoffs (`tscon %SessionId% /dest:console`) attach directly to the physical RTX 3060 display adapter without triggering HDMI-CEC input switching or video signal interruptions on the television.
   * **Zero-LPE Security Boundary:** Creating an unhardened scheduled task running as `NT AUTHORITY\SYSTEM` triggerable by standard user `gamer` introduces a classic Local Privilege Escalation (LPE) vulnerability (MITRE ATT&CK T1053.005) via script replacement. The architecture strictly mandates that `gamer` possesses **zero elevated tasks**; all console handoffs are driven over authenticated OpenSSH from the Workstation using administrative `benka_000` ed25519 keys.
   * **Pragmatic Game Management:** Headless CLI game installation across multi-drive Steam libraries proved brittle due to interactive drive-picker modals. Game installations are designated as occasional visual RDP operations, while daily gaming operates 100% headlessly.

## Action
1. **Implementation Steps:**
   * Provisioned dedicated local standard user `gamer` on `rath15-htpc`, assigned to the `Remote Desktop Users` security group with non-expiring credentials stored in Windows Credential Manager (`TERMSRV/rath15-htpc`).
   * Configured Steam on HTPC for target account `coppertrumpet2`, secured a long-lived persistent OAuth/JWT session token (valid through April 2027), and updated `loginusers.vdf` and `config.vdf` (`AlwaysShowUserChooser: 0`, `AutoLogin: 1`) to eliminate interactive account-picker prompts on headless start.
   * Deployed `switch_and_stream.ps1` and `do_tscon.ps1` to orchestrate session inspection, background RDP handshake, one-shot temporary SYSTEM `tscon` console attachment, and verification of Steam Remote Play TCP port `27036`.
   * Created non-invasive desktop telemetry tool `get_screenshot.ps1` with Win32 DPI awareness to verify GUI dialog states without user disruption.
   * Successfully installed *Batman: Arkham Asylum GOTY Edition* to `F:\SteamLibrary\steamapps\common\Batman Arkham Asylum GOTY` (8.47 GB).
   * Verified hardware-accelerated NVENC H.264 video streaming at 60 FPS, Steam Streaming Speakers low-latency audio, and Xbox wireless controller input routing via Steam Input.
2. **Key Parameters:**
   * Host Node: `rath15-htpc` (`192.168.68.162`), Windows 11 Pro, RTX 3060 (Driver `32.0.15.9621`)
   * Shared Steam Account: `coppertrumpet2`
   * Networking Ports: TCP `27036` (Control), UDP `27031` / `27036` (Streaming Transport)
   * Local Libraries: `F:\SteamLibrary` (147 GB free), `H:\SteamLibrary` (372 GB free)

## Consequences
* **Positive:** Unlocked high-framerate PC gaming powered by remote RTX 3060; zero television disruptions; complete separation between development and gaming identities.
* **Operational:** Installing new games is performed visually via RDP as `gamer`; post-install handoff or daily gaming is executed via `switch_and_stream.ps1`.
* **Security:** User `gamer` is strictly unprivileged; elevated console switching is confined to authenticated SSH administration with zero persistent privilege escalation vectors.

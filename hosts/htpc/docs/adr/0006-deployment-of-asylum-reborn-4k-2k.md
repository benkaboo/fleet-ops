# ADR-0006: Deployment of "Asylum Reborn" 4K/2K HD Texture Overhaul and Standalone Advanced Launcher for Batman: Arkham Asylum

* **Status:** Accepted
* **Date:** 2026-09-11
* **Component:** Gaming & Streaming
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **The Problem / Requirement:** Remastered 4K/2K visual fidelity was required for *Batman: Arkham Asylum GOTY* on `rath15-htpc`. The vanilla textures (compiled in 2009) exhibited visible blur and compression on modern displays. The overhaul required a solution without volatile runtime memory injection (TexMod/uMod), without requiring administrator rights for the unprivileged user `gamer`, and without introducing stability or streaming regressions.
2. **Constraints & Trade-offs:**
   * **Engine Architecture:** Unreal Engine 3 compiles texture caches into `.tfc` packages (`Textures.tfc`). Natively patching textures requires permanent package injection rather than fragile memory hooks.
   * **Zero-LPE Security:** Dedicated gaming user `gamer` has zero administrative rights and cannot install system-wide .NET runtimes. Any third-party launcher must run standalone or leverage pre-installed runtimes.
   * **Pre-Flight Antivirus Defense:** All downloaded mod archives, executables, and batch scripts must undergo verification scans via Microsoft Defender before staging and execution.
   * **Reversibility & Rollback:** Vanilla texture archives (~945 MB) and executables must be fully backed up to allow instantaneous recovery without redownloading through Steam.

## Action
1. **Implementation Steps:**
   * Scanned all incoming packages with Microsoft Defender Antivirus (`MpCmdRun.exe`), verifying zero threats across `Asylum Reborn - HD Texture Pack` (550 MB), `Batman Arkham Asylum - Advanced Launcher Standalone` (250 MB), and `TFC Installer` (9.4 MB).
   * Backed up vanilla game assets: `Textures.tfc` (945 MB) ➡️ `Textures.tfc.vanilla.bak` and `BmLauncher.exe` (8.5 MB) ➡️ `BmLauncher.exe.vanilla.bak`.
   * Deployed Neato's standalone .NET 8 `BmLauncher.exe` (self-contained 250 MB binary) into `F:\SteamLibrary\steamapps\common\Batman Arkham Asylum GOTY\Binaries\`, eliminating all external framework dependencies.
   * Injected 4K/2K DirectDraw Surface (`.dds`) textures into `CookedPC` using `TFCInstaller.exe` in an isolated staging workspace, generating `Texture2D_0.tfc` (578 MB) and patching 351 map and character packages.
   * Tuned engine parameters in `BmEngine.ini`: expanded `PoolSize` from vanilla 120 MB to 2048 MB VRAM allocation, and enabled high-res LOD overrides across `Character`, `World_Hi`, `WorldNormalMap_Hi`, and `Cinematic` texture groups.
   * Executed headless console handoff via `switch_and_stream.ps1`, binding `gamer` to the physical RTX 3060 adapter with verified Remote Play port `27036` connectivity.
2. **Key Parameters:**
   * Game Installation: `F:\SteamLibrary\steamapps\common\Batman Arkham Asylum GOTY`
   * Target Texture Cache: `BmGame\CookedPC\Texture2D_0.tfc` (577,694,792 bytes)
   * Engine Configuration: `BmEngine.ini` (`PoolSize=2048`, `Texture Pack Support: Enabled`)
   * Vanilla Backups: `Textures.tfc.vanilla.bak` (991,494,144 bytes), `BmLauncher.exe.vanilla.bak` (8,579,400 bytes)
   * Launcher: Standalone .NET 8 `BmLauncher.exe` v2.1.0.5

## Consequences
* **Positive:** Unlocked 4K/2K remastered visuals streamed headlessly at 60 FPS powered by RTX 3060 NVENC encoding; zero runtime memory injection instability; native engine texture streaming.
* **Operational:** Mod management is fully decoupled from daily gaming; vanilla state is 100% recoverable instantly via `.vanilla.bak` restores without Steam redownload.
* **Security:** All binaries verified clean by Defender; zero privilege elevation required; standard user `gamer` remains strictly sandboxed.

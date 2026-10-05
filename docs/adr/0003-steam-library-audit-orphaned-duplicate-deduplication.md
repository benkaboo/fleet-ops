# ADR-0003: Steam Library Audit, Orphaned Duplicate Deduplication, and Target Uninstallation

* **Status:** Accepted
* **Date:** 2026-09-10
* **Component:** Gaming & Streaming
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **The Problem / Requirement:** Following initial host stabilization, physical mechanical HDD partitions (`F:`, `G:`, `H:`) remained constrained with low free space warnings (8.1% on `F:`, 9.4% on `G:`, 7.4% on `H:`). A comprehensive remote audit of Steam game libraries across all drives revealed an orphaned library root on `G:\SteamLibrary` containing 85 installed games (492 GB) not registered in Steam's client `libraryfolders.vdf` configuration. This unlinked library caused duplicate full-game downloads across active libraries on `F:\` and `H:\`, consuming over 230 GB in redundant storage.
2. **Constraints & Trade-offs:**
   * **Protected Game Assets:** *Black Myth: Wukong* (139.6 GB on `H:\SteamLibrary`) had to be strictly preserved without modification.
   * **Game Save State Safety:** User save progress, cloud synchronization, and local user profile state (`AppData\Local`, `Saved Games`, `Documents`) could not be impacted.
   * **Living Room Stability:** All operations had to run remotely over SSH in the background without launching the Steam GUI or interrupting active media playback.
   * **Active Copy Verification:** Proved active copies were on `F:` and `H:` by inspecting `appmanifest_*.acf` metadata (`LastPlayed` timestamps indicating recent 2025–2026 activity, contrasted with `LastPlayed: 0` on `G:\`).

## Action
1. **Implementation Steps:**
   * Audited 250 game installations (~2.61 TB) across `C:`, `F:`, `G:`, and `H:`, cataloging active vs. orphaned installations and publishing [`reports/steam_library_audit.md`](reports/steam_library_audit.md).
   * Targeted for uninstallation user-approved titles: *Sea of Thieves* (AppID 1172620, 102.5 GB on `H:\`), *AFL 26* (AppID 3468640, 30.8 GB on `H:\`), *Zero Caliber VR* (AppID 877200, 40.9 GB across `F:\` and `H:\`), and *Disney Infinity 3.0* (AppID 541670, 24.7 GB across `F:\` and `G:\`).
   * Targeted 30 orphaned duplicate game directories and unlinked app manifests in `G:\SteamLibrary` for deletion while retaining verified active copies on `F:\` and `H:\`.
   * Executed purge automation script over SSH (`task-375`) deleting target game common directories and corresponding `appmanifest_*.acf` files.
   * Verified directory removal and recorded post-purge partition space metrics.
2. **Key Parameters:**
   * Games Uninstalled: *Sea of Thieves* (`H:\SteamLibrary`), *AFL 26* (`H:\SteamLibrary`), *Zero Caliber VR* (`F:\` and `H:\`), *Disney Infinity 3.0* (`F:\` and `G:\`).
   * Orphaned Duplicates Purged: 30 titles from `G:\SteamLibrary\steamapps\common\` (including *STAR WARS Jedi: Fallen Order*, *Batman Arkham City*, *Planet Coaster*, *Raft*, *Hollow Knight*, *Terraria*, *Totally Accurate Battle Simulator*, etc.).
   * Retained Active Game: *Black Myth: Wukong* (`H:\SteamLibrary\steamapps\common\BlackMythWukong`, 139.57 GB).
   * Storage Reclaimed (Purge): **515.2 GB** across mechanical drives (`F:\` +68.6 GB, `G:\` +156.5 GB, `H:\` +290.1 GB).
   * Cumulative Storage Reclaimed (Session): **556.9 GB** mechanical storage (+16.5 GB SSD storage).
3. **Verification & Testing:**
   * Confirmed zero script execution errors in `scratch/purge_output.json`.
   * Executed `Test-Path` check over SSH to confirm *Black Myth: Wukong* directory is intact and valid.
   * Queried remote `Get-PSDrive` via SSH confirming final free space: `C:\` at 479.1 GB (51.5%), `F:\` at 155.4 GB (11.1%), `G:\` at 298.8 GB (31.2%), and `H:\` at 372.6 GB (27.3%).
   * Total free mechanical storage verified at **826.8 GB** (up from 269.9 GB initial baseline).

## Consequences
* **Positive:** Reclaimed over half a terabyte (515.2 GB) in unneeded games and orphaned duplicates; completely cleared low disk space pressure across all 3 mechanical partitions; improved mechanical drive seek performance.
* **Operational:** `G:\SteamLibrary` is now deduplicated; all active Steam library folders on `F:` and `H:` remain clean and registered in `libraryfolders.vdf`.
* **Security & Reliability:** Zero user save data lost; strictly preserved all protected titles and system integrity.

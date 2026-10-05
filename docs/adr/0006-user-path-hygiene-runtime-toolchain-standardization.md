# ADR-0006: User PATH Hygiene & Runtime Toolchain Standardization

* **Status:** Accepted
* **Date:** 2026-09-08
* **Component:** Storage & Backup
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **The Problem / Requirement:** The User PATH environment variable (`HKCU:\Environment`) contained an invalid file path pointer (`C:\Program Files\nodejs\node.exe` instead of a directory) and lingering pointers to Python 3.12 (`C:\Users\benma\AppData\Local\Programs\Python\Python312\`). This caused runtime version collision with the primary Python 3.14 toolchain configured in System PATH (`C:\Python314\`), leading to command resolution ambiguity across terminal shells.
2. **Constraints & Trade-offs:** Node.js execution must remain unaffected (authoritatively handled by `C:\Program Files\nodejs\` in System PATH). Python 3.14 must become the unambiguous primary interpreter. User PATH changes must be fully restorable via automated tooling.

## Action
1. **Implementation Steps:**
   * Backed up current raw User PATH string to `reports/backup_user_path.txt`.
   * Created reversible maintenance scripts `scripts/optimize_user_path.ps1` and `scripts/restore_user_path.ps1`.
   * Executed `scripts/optimize_user_path.ps1` removing `node.exe` and `Python312` paths from `HKCU:\Environment`.
   * Broadcasted environment update `WM_SETTINGCHANGE` to running shells.
   * Updated `ARCHITECTURE.md` Section 6.1 and Section 9 (Architectural Tradeoffs table).
2. **Key Parameters:**
   * Target Resource: `HKCU:\Environment` (`Path`)
   * Pruned Entries:
     * `C:\Program Files\nodejs\node.exe`
     * `C:\Users\benma\AppData\Local\Programs\Python\Python312\Scripts\`
     * `C:\Users\benma\AppData\Local\Programs\Python\Python312\`
   * Unified Python: `Python 3.14.6` at `C:\Python314\python.exe`
   * Reversal Script: `scripts/restore_user_path.ps1`
3. **Verification & Testing:**
   * Verified User PATH contains only valid directories (`agy\bin`, `Python\Launcher`, `WindowsApps`, `VS Code\bin`, `npm`, `Antigravity IDE\bin`, `rclone`).
   * Executed `python --version` -> `Python 3.14.6`.
   * Executed `node --version` -> `v24.16.0`.
   * Validated `agy`, `npm`, and `git` command resolution.

## Consequences
* **Positive:** Restored clean PATH directory syntax, eliminated version shadowing between Python 3.12 and 3.14, and unified execution across all developer shells.
* **Operational:** Running `python` explicitly targets 3.14. If Python 3.12 is ever needed for a legacy project, it remains installed on disk and can be referenced directly or managed via virtual environments (`py -3.12 -m venv`).
* **Security:** Reduced PATH traversal risks from invalid file references.

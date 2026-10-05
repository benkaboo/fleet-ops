# ADR-0002: Hardened OpenSSH Remote Management Channel & Ed25519 Authentication

* **Status:** Accepted
* **Date:** 2026-09-09
* **Component:** Security & Governance
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **The Problem / Requirement:** Physical administration of `rath15-htpc` in the living room requires local keyboard access. Prior Remote Desktop (RDP) login attempts failed due to local user account naming discrepancies (`benka_000` created during Microsoft Account setup). Furthermore, connecting via RDP terminates or locks the physical display, interrupting TV playback and media rendering.
2. **Constraints & Trade-offs:** Remote management must be secure, lightweight, and capable of background execution without disrupting living room display output or media streams.

## Action
1. **Implementation Steps:**
   * Deployed Microsoft OpenSSH Server (`OpenSSH-Win64`) to `C:\Program Files\OpenSSH` on `rath15-htpc`.
   * Configured Windows Service `sshd` to start automatically on system boot.
   * Created inbound Windows Firewall rule restricting TCP port 22 strictly to `LocalSubnet` (`192.168.68.0/24`) on the `Private` network profile.
   * Deployed Ben's workstation Ed25519 public key to `C:\ProgramData\ssh\administrators_authorized_keys` with strict Windows ACL permissions (`SYSTEM` and `Administrators` only).
   * Configured workstation SSH client alias `Host rath15-htpc` pointing to `192.168.68.162` with user `benka_000`.
2. **Key Parameters:**
   * Node IP: `192.168.68.162`
   * Target Port: `22` (TCP - LocalSubnet Only)
   * Local User: `benka_000`
   * Key: Ed25519 Asymmetric Cryptography
3. **Verification & Testing:**
   * Verified port 22 open and responsive via socket probe.
   * Executed passwordless remote command `whoami & hostname` over SSH; confirmed deterministic execution without password prompts.

## Consequences
* **Positive:** High-security, cryptographically authenticated remote administration established. Zero password transmission over the network.
* **Operational:** Remote maintenance, diagnostics, and updates can now be run completely in the background without affecting the living room TV screen or media playback.
* **Security:** Attack surface minimized by binding port 22 strictly to the local home subnet.

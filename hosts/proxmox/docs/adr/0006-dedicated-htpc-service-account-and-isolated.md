# ADR-0006: Dedicated HTPC Service Account and Isolated [Media] Samba Share

* **Status:** Accepted
* **Date:** 2026-09-06
* **Component:** Media & Applications
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Optical Media Ripping Workflow:** The Home Theatre PC (`rath15-htpc`, `192.168.68.162`) requires direct filesystem write access to the media repository (`/mnt/simba/Media`) to dump DVD and Blu-ray rips (MakeMKV, Handbrake) directly into `Movies`, `TV Shows`, and `Music`.
2. **Windows Multi-Session Collision:** Windows clients permit only one authenticated user context per target server IP/hostname. When the HTPC connected anonymously or with local machine credentials (due to Samba's `map to guest = Bad User`), subsequent attempts to authenticate to `[simba]` as `bjm` triggered client-side Windows error 1219 (*"Multiple connections to a server or shared resource by the same user, using more than one user name, are not allowed"*).
3. **Least Privilege & Ownership Isolation:** Granting the living-room HTPC full access to the root `[simba]` share exposed personal backups and documents. Furthermore, adding `htpc` to the operator's User Private Group (`bjm`) violated least privilege.

## Action
1. **Isolated Linux Service Account:**
   * Created dedicated system user `htpc` (UID 1003) on `rath15nas` with disabled interactive login shell (`/usr/sbin/nologin`), no home directory (`-M`), and standard membership in primary group `users` (GID 100).
   * User `htpc` is explicitly excluded from the administrative `bjm` and `sudo` groups.
2. **Dedicated `[Media]` Share Configuration (`smb.conf`):**
   * Added share `[Media]` mapped to `/mnt/simba/Media` restricted to `valid users = bjm, htpc`.
   * Configured Samba identity forcing: `force user = bjm` and `force group = bjm`.
   * Configured creation masks `force create mode = 0664` and `force directory mode = 0775`.
3. **Deployment Automation:**
   * Created [`scripts/setup-htpc-media-share.sh`](scripts/setup-htpc-media-share.sh) and PowerShell wrapper [`scripts/deploy-htpc-media.ps1`](scripts/deploy-htpc-media.ps1) with automated configuration backup and service reload (`systemctl reload smbd.service`).
4. **Client-Side Mount Configuration:**
   * Cleared stale anonymous sessions on HTPC and registered dedicated credentials in Windows Credential Manager:
     `cmdkey /add:192.168.68.169 /user:htpc /pass:<secret>`
     `net use M: \\192.168.68.169\Media /persistent:yes`

## Consequences
* **Positive:** Seamless DVD ripping directly to `M:\Movies`, `M:\TV Shows`, and `M:\Music` without exposing personal files or backups in `/mnt/simba`.
* **Positive:** All files created by the HTPC are written on disk as `bjm:bjm`, eliminating file-ownership discrepancies with the operator's primary workstation.
* **Positive:** Permissions `0664`/`0775` guarantee that the unprivileged Jellyfin container (LXC 920) can read and index newly ripped media immediately.
* **Positive:** Client-side Windows session conflicts are permanently resolved via dedicated Credential Manager mapping.
* **Security:** `htpc` has zero SSH or terminal access to the Proxmox hypervisor.

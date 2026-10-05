# ADR-0007: FileBrowser Web Manager, AdGuard Home Local DNS, and `*.dixon.home` Dual-Stack Routing

* **Status:** Accepted
* **Date:** 2026-09-07
* **Component:** Networking / VPN
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Local Domain Ergonomics & High Privacy:** Navigating to homelab services required memorizing long IP-based domains (`https://<service>.192.168.68.175.nip.io`), which depended on public cloud DNS resolution and lacked privacy. The operator required human-friendly local naming (`*.dixon.home`) with zero external DNS leakage and network-wide ad blocking.
2. **Browser & SSO Domain Hierarchy:** Modern web browsers (Chromium, Gecko, WebKit) and Authelia SSO enforce cookie security specifications prohibiting single-label domain cookies (`dixon`). A multi-label internal domain (`dixon.home`) is required to enable cross-subdomain SSO session persistence.
3. **Web-Based Storage Management:** The operator required a lightweight web file manager to browse, upload, download, and organize files across `/mnt/simba` (`Books`, `Documents`, `Media`, `Scripts`, `Shared-All-Family`) without requiring Samba client configuration on every device.

## Action
1. **FileBrowser Deployment (`10-deploy-filebrowser.sh`):**
   * Deployed `filebrowser/filebrowser:latest` in `/opt/stacks/filebrowser/compose.yaml` on host port `8082`.
   * Bind-mounted `/mnt/simba` into `/srv` with permissions `1000:1000`.
   * Enforced minimum 12-character administrative credential policy (`MediaAdmin2026!`).
   * Integrated into Caddy with Authelia forward authentication (`import authelia-auth`).
2. **AdGuard Home Deployment (`12-deploy-adguard.sh`):**
   * Deployed `adguard/adguardhome:latest` in `/opt/stacks/adguard/compose.yaml` with host port `53` (TCP/UDP) and initial wizard on port `3000`.
   * Configured `systemd-resolved` stub listener deactivation on host `0.0.0.0:53` while preserving PVE upstream resolution via `/etc/resolv.conf`.
   * Initialized administrative portal (`dixon_admin`) and configured wildcard DNS rewrite `*.dixon.home` $\rightarrow$ `192.168.68.175`.
3. **Dual-Stack Caddy & Multi-Domain Authelia SSO (`13-configure-dixon-home.sh`):**
   * Configured Authelia `session.cookies` for multi-domain support (`dixon.home` and `192.168.68.175.nip.io`) and added access control rules for `auth.dixon.home` (bypass) and `*.dixon.home` (one_factor).
   * Configured Caddy `(authelia-auth)` forward-auth snippet to dynamically handle redirect URLs based on the incoming request domain.
   * Updated Caddy site blocks to serve both `.dixon.home` and `.192.168.68.175.nip.io` with automatic internal PKI TLS certificates.
   * Validated HTTPS routes: `auth`, `dockge`, `jellyfin`, `books`, `files`, and `adguard`.

## Consequences
* **Positive:** Clean, intuitive, memorable URLs across all home services (`https://jellyfin.dixon.home`, `https://files.dixon.home`, `https://books.dixon.home`, etc.).
* **Positive:** 100% offline resolution; services remain fully operational and resolvable even during complete internet connectivity outages.
* **Positive:** Network-wide ad and telemetry blocking active for all devices querying AdGuard DNS (`192.168.68.175`).
* **Positive:** Zero breaking changes; legacy `*.192.168.68.175.nip.io` URLs remain fully functional as fallbacks.
* **Security:** No internal network records, hostnames, or private IPs leaked to public DNS. All sensitive credentials preserved outside version control.

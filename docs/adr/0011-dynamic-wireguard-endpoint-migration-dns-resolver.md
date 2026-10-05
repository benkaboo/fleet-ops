# ADR-0011: Dynamic WireGuard Endpoint Migration (`maslen.id.au`) & DNS Resolver Remediation

* **Status:** Accepted
* **Date:** 2026-09-13
* **Component:** Networking / VPN
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Remote Peer ISP Migration:** The remote WireGuard peer router changed ISP, resulting in a public IP transition from `203.132.95.12` to `157.85.240.12` (managed via dynamic DNS hostname `maslen.id.au`). Because `/etc/wireguard/wg0.conf` on `rath15nas` had the deprecated IP hardcoded as its peer endpoint, the site-to-site VPN connection dropped and failed to renegotiate handshakes.
2. **Broken Host DNS Resolver:** During incident triage, `/etc/resolv.conf` on `rath15nas` was found to be pointing exclusively to `119.40.106.35` (Superloop upstream DNS), which refused recursive DNS queries following the network migration. Consequently, the host could not resolve any hostnames (including `maslen.id.au`), preventing dynamic DNS resolution upon service restart.

## Action
1. **DNS Resolver Remediation:**
   * Backed up `/etc/resolv.conf` to a timestamped backup file.
   * Updated `/etc/resolv.conf` to declare the local LAN gateway (`192.168.68.1`) and Cloudflare public resolver (`1.1.1.1`) alongside the local domain search (`benevolency.com`).
   * Validated hostname resolution: `maslen.id.au` dynamically resolved to `157.85.240.12`.
2. **WireGuard Configuration Update:**
   * Backed up `/etc/wireguard/wg0.conf` to a timestamped backup file.
   * Replaced the hardcoded endpoint (`203.132.95.12:51820`) with dynamic hostname `Endpoint = maslen.id.au:51820`.
   * Preserved strict file permissions (`chmod 600 /etc/wireguard/wg0.conf`).
3. **Service Reload & Automated Verification:**
   * Restarted `wg-quick@wg0.service`.
   * Confirmed successful WireGuard handshake and active traffic counters via `wg show wg0`.
   * Validated end-to-end ICMP ping across the tunnel to `10.10.0.1` (0% packet loss, ~19ms latency) and remote subnet `192.168.6.1` (0% packet loss, ~22ms latency).
4. **Remediation Scripting:**
   * Authored automated deployment scripts [`scripts/update-wireguard-endpoint.sh`](scripts/update-wireguard-endpoint.sh) and [`scripts/update-wireguard-endpoint.ps1`](scripts/update-wireguard-endpoint.ps1) adhering to Rule 5 staging patterns.

## Consequences
* **Positive:** WireGuard site-to-site VPN link and cross-subnet routing (`192.168.6.0/24`) are fully restored.
* **Positive:** Future IP changes on the remote peer will automatically be absorbed upon interface restart or DNS cache refresh via dynamic hostname resolution.
* **Positive:** `rath15nas` hypervisor host DNS resolution is stabilized with dual redundant resolvers.

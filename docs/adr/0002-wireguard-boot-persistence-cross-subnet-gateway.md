# ADR-0002: WireGuard Boot Persistence & Cross-Subnet Gateway Routing

* **Status:** Accepted
* **Date:** 2026-09-06
* **Component:** Networking / VPN
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Reboot Persistence:** WireGuard was previously started interactively/manually without systemd service management. On host reboot, the tunnel would not automatically reconnect.
2. **Cross-Subnet Access:** Operator workstations on the local LAN (`192.168.68.0/24`) need to reach the remote peer network (`192.168.6.0/24`) across the WireGuard tunnel. The Proxmox host lacked kernel packet forwarding and NAT masquerading, causing packets to be dropped or rejected due to asymmetric routes and WireGuard cryptokey routing constraints.

## Action
1. **Phase 1 (Persistence):**
   * Enabled `wg-quick@wg0.service` in systemd (`systemctl enable wg-quick@wg0`) to ensure tunnel creation on boot milestone.
   * Validated tunnel endpoint connectivity (`ping -c 3 10.10.0.1`) and handshake status.
2. **Phase 2 (Cross-Subnet Gateway):**
   * Enabled IPv4 kernel forwarding (`sysctl -w net.ipv4.ip_forward=1`).
   * Configured NAT masquerading on the WireGuard egress interface (`iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE`).
   * Configured stateful filter forwarding rules (`iptables -A FORWARD -d 192.168.6.0/24 -o wg0 -j ACCEPT` and `iptables -A FORWARD -i wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT`).
   * Defined static route on client workstation: `route -p add 192.168.6.0 mask 255.255.255.0 192.168.68.169`.
3. **Phase 3 (Persistence Lock-In & Privilege Revocation):**
   * Appended `PostUp` and `PostDown` hooks into `/etc/wireguard/wg0.conf` for automatic iptables lifecycle management.
   * Persisted kernel forwarding across boots via `/etc/sysctl.d/99-wireguard-forwarding.conf`.
   * Revoked temporary scoped permissions (`/etc/sudoers.d/agy-wireguard`), returning `agy-auditor` strictly to least-privilege read-only inspection (`/etc/sudoers.d/agy-readonly`).
   * Tagged release: `v1.0-wireguard-routing`.

## Consequences
* **Positive:** Complete host-side WireGuard and routing lifecycle automatically persists across reboots.
* **Positive:** Local LAN clients can transparently route traffic to `192.168.6.0/24` via Proxmox (`192.168.68.169`) without requiring changes to the remote peer's router or AllowedIPs list.
* **Security:** `agy-auditor` credentials and privileges are strictly locked down to read-only diagnostics; secrets remain isolated from automation.

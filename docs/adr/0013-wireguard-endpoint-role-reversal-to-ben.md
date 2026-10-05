# ADR-0013: WireGuard Endpoint Role Reversal to Ben Dedicated Static IPv4 (`157.85.240.10:51820`)

* **Status:** Accepted
* **Date:** 2026-09-20
* **Component:** Networking / VPN
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Peer Static IP Loss & IPv4 DNS Deprecation:** The remote peer router (Brother) lost its static public IPv4 address, and its dynamic DNS domain (`maslen.id.au`) transitioned exclusively to an IPv6 `AAAA` record (`2401:d002:b504:3300::1`), dropping all IPv4 records. Because `rath15nas` was acting as an outbound initiator seeking `maslen.id.au:51820`, the site-to-site VPN link experienced a ~1.7-day outage.
2. **Asymmetric Network Topology:** Ben's Neptune Internet connection (`AS151660`) was validated to possess a dedicated, permanent static public IPv4 address (`157.85.240.10`) with PTR `ip-157.85.240.10.neptune.net.au`. Reversing endpoint roles allows the brother to connect outbound from behind dynamic IP or CGNAT, relying on WireGuard dynamic endpoint roaming.

## Action
1. **Proxmox Host Reconfiguration (`rath15nas`):**
   * Staged and executed [`scripts/reconfigure-wireguard-listener.sh`](scripts/reconfigure-wireguard-listener.sh).
   * Updated `/etc/wireguard/wg0.conf` to set `ListenPort = 51820` under `[Interface]`.
   * Removed stale outbound `Endpoint = maslen.id.au:51820` under `[Peer]`, configuring `rath15nas` as a passive listening endpoint.
   * Restarted `wg-quick@wg0.service`. Verified socket binding on `0.0.0.0:51820` and `[::]:51820`.
2. **Deco M9 Router Port Forwarding:**
   * Configured external port forward on TP-Link Deco M9 (`192.168.68.1`): `UDP 51820` $\rightarrow$ `192.168.68.169:51820`.
3. **Peer Coordination:**
   * Provided drop-in configuration for remote peer pointing to `Endpoint = 157.85.240.10:51820` with `PersistentKeepalive = 25`.
4. **Verification:**
   * Handshake established immediately (`wg show wg0` confirmed roaming endpoint `115.70.61.168:50284`).
   * ICMP ping across tunnel to `10.10.0.1` succeeded (0% packet loss, ~19ms latency).
   * Cross-subnet ping to remote LAN `192.168.6.1` succeeded from both `rath15nas` (~19ms) and Windows workstation (~26ms).

## Consequences
* **Positive:** Site-to-site VPN tunnel and cross-subnet routing (`192.168.6.0/24`) are fully restored.
* **Positive:** Brother is completely insulated from future ISP dynamic IP or CGNAT changes; WireGuard automatically updates its roaming endpoint upon receiving keepalive packets.
* **Security:** Public attack surface remains strictly bounded to a single silent UDP port (`51820`).

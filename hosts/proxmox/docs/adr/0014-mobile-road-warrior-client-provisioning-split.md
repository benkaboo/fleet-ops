# ADR-0014: Mobile Road-Warrior Client Provisioning (`10.10.0.5/32`) & Split-Tunneling

* **Status:** Accepted
* **Date:** 2026-09-20
* **Component:** Networking / VPN
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
Operator required secure, encrypted remote access to homelab services (Jellyfin, Books, Proxmox GUI, Samba shares, and remote brother network) while away from home on mobile cellular or untrusted Wi-Fi.

## Action
1. **Provisioning Script:** Created [`scripts/add-wireguard-client.sh`](scripts/add-wireguard-client.sh) and [`scripts/deploy-add-client.ps1`](scripts/deploy-add-client.ps1).
2. **Key Generation & Dynamic Peer Registration:**
   * Generated dedicated Curve25519 keypair on `rath15nas`.
   * Dynamically registered peer `10.10.0.5/32` using `wg set wg0 peer <pubkey> allowed-ips 10.10.0.5/32` with zero downtime to the active brother tunnel.
   * Persisted peer block in `/etc/wireguard/wg0.conf`.
3. **LAN Egress NAT Masquerade:**
   * Added `iptables -t nat -A POSTROUTING -s 10.10.0.0/24 -o vmbr0 -j MASQUERADE` and persisted rule in `wg0.conf` `PostUp`/`PostDown`.
4. **Client Profile & Terminal QR Code:**
   * Generated split-tunnel client configuration with `AllowedIPs = 192.168.68.0/24, 192.168.6.0/24, 10.10.0.0/24` and DNS set to AdGuard Home (`192.168.68.175`).
   * Rendered ANSI UTF-8 QR code in terminal using `qrencode`.
   * Securely wiped client private keys and temporary profiles from server disk post-scan.

## Consequences
* **Positive:** Operator can securely connect from anywhere via official WireGuard app on Google Pixel phone.
* **Positive:** Split-tunnel design routes homelab and DNS traffic over VPN while preserving direct cellular speeds for general internet streaming.
* **Positive:** Network-wide ad-blocking and `*.dixon.home` resolution are active on mobile data via AdGuard Home.

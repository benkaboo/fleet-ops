# Gateway Router Blueprint (`hosts/router`)

This directory maintains the physical configuration, network routing policies, static DHCP maps, and Architectural Decision Records (ADRs) for the primary edge gateway router.

---

## 1. Device Hardware & Management

* **Device / Model:** *(e.g., UniFi Gateway Ultra / OPNsense Appliance / pfSense / ASUS RT-AX88U)*
* **Firmware Version:** *(Track active firmware version)*
* **Management Web UI:** `https://192.168.68.1` (or new gateway IP)
* **Credentials:** Managed in Bitwarden / 1Password under `Homelab Router Admin` (Zero raw passwords in Git).

---

## 2. Network Topology & Subnet Plan

| Zone / VLAN | CIDR Subnet | Gateway IP | DHCP Pool Range | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **LAN (Default)** | `192.168.68.0/24` | `192.168.68.1` | `.100 - .250` | Primary trusted devices, hypervisor, workstation |
| **Servers / Infrastructure** | `192.168.68.0/24` | `192.168.68.1` | Static (`.150 - .199`) | Proxmox (`.169`), Services LXC (`.175`), HTPC (`.150`) |
| **IoT / Smart Home** | *(Planned VLAN)* | - | - | Isolated untrusted devices & Home Assistant |

---

## 3. Critical Static DHCP Reservations

| MAC Address | Reserved IP | Hostname | Device / Role |
| :--- | :--- | :--- | :--- |
| *(Hardware MAC)* | `192.168.68.169` | `rath15nas` | Proxmox VE 8.x Hypervisor host |
| *(Hardware MAC)* | `192.168.68.175` | `services` | LXC 920 (Docker, Caddy, Immich, Jellyfin) |
| *(Hardware MAC)* | `192.168.68.150` | `htpc` | Living Room Streaming Target |

---

## 4. Port Forwarding & Ingress Rules

| WAN / Ingress Port | Protocol | Target IP | Target Port | Service Description |
| :--- | :--- | :--- | :--- | :--- |
| `51820` | `UDP` | `192.168.68.169` | `51820` | WireGuard Site-to-Site & Road-Warrior tunnel |
| `80` *(optional)* | `TCP` | `192.168.68.175` | `80` | ACME HTTP-01 challenge (if not using DNS-01) |
| `443` *(optional)* | `TCP` | `192.168.68.175` | `443` | External HTTPS Ingress via Caddy |

---

## 5. Configuration Backups (`configs/`)

* Stored in [`configs/`](configs/): Exported configuration files (JSON, XML, or CLI rule exports).
* **Sanitization Mandate (Rule 4):**
  * Remove PPPoE ISP credentials, pre-shared Wi-Fi keys, and private keys before committing.
  * Use `.env.example` style placeholders (e.g., `<PPPOE_PASSWORD_VAULT_REF>`).

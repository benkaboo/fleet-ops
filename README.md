# Fleet Operations & Knowledge Repository (`fleet-ops`)

Central repository for all Dixon Homelab infrastructure blueprints, disaster recovery runbooks, host setup automation, and Architectural Decision Records (ADRs).

---

## 1. Quick Navigation

* 🗺️ **[Fleet Topology & Directory](docs/fleet-topology.md):** Consolidated subnets, IP assignments, host hardware specs, and container ports.
* 🚨 **[Cold-Start Disaster Recovery](docs/COLD_START_DISASTER_RECOVERY.md):** Step-by-step bare-metal recovery procedure to rebuild the fleet from scratch.
* 📦 **[Companion Runtime Repo: homelab-stacks](https://github.com/benkaboo/homelab-stacks):** Declarative Docker Compose stacks deployed on LXC 920.

---

## 2. Repository Structure

```text
fleet-ops/
├── .gitignore                          <-- Fleet-wide secret boundaries (*.env, *.key, *.pem)
├── README.md                           <-- Master navigation guide
├── docs/
│   ├── COLD_START_DISASTER_RECOVERY.md <-- Step-by-step disaster recovery playbook
│   └── fleet-topology.md               <-- Consolidated IP / VLAN / Port / Host map
├── hosts/
│   ├── proxmox/                        <-- Proxmox VE 8 hypervisor, GPU passthrough & 25 ADRs
│   │   ├── docs/adr/                   <-- Indexed architectural decision records
│   │   ├── scripts/                    <-- Host & LXC bootstrap scripts
│   │   └── ARCHITECTURE.md
│   ├── workstation/                    <-- Windows 11 primary workstation & 13 ADRs
│   │   ├── docs/adr/
│   │   ├── configs/
│   │   └── scripts/
│   ├── htpc/                           <-- HTPC living room streaming node & 7 ADRs
│   │   ├── docs/adr/
│   │   └── scripts/
│   ├── router/                         <-- Edge gateway router blueprint, firewall rules & configs
│   │   ├── docs/adr/
│   │   └── configs/
│   └── remotegaming/                   <-- Sunshine / Steam headless game streaming scripts
└── storage/
    └── update_fstab_btrfs.sh           <-- Storage pool mount automation
```

---

## 3. Architectural Decision Records (ADRs)

All architectural changes across the fleet are documented in lightweight, atomic ADRs following the Keep a Changelog standard governed by `personal-governance`:

* **[Proxmox ADR Index](hosts/proxmox/docs/adr/README.md)** (25 ADRs)
* **[Workstation ADR Index](hosts/workstation/docs/adr/README.md)** (13 ADRs)
* **[HTPC ADR Index](hosts/htpc/docs/adr/README.md)** (7 ADRs)
* **[Router ADR Index](hosts/router/docs/adr/README.md)** (Pending)

---

## 4. Governance & Git Hygiene

* **Rule 4 (Zero Secret Leakage):** Plaintext credentials, private keys, `.env` files, and persistent SQLite databases are strictly excluded via `.gitignore`.
* **Atomic Fleeting Tagging:** Tag critical fleet milestones using `git tag -a <version> -m "<description>"`.

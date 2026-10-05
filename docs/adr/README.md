# Architectural Decision Records (ADRs)

This directory contains the immutable, chronological record of architectural, infrastructure, and governance decisions for the Proxmox and WireGuard homelab environment.

Decisions follow the standard **Context -> Action -> Consequences** format governed by the `changelog-discipline` and `knowledge-gardener` skills.

## ADR Index

| ID | Date | Component | Title | Status |
| :--- | :--- | :--- | :--- | :--- |
| [ADR-0025](0025-immich-photo-storage-privacy-isolation-native.md) | 2026-10-05 | Hardware / GPU | Immich Photo Storage Privacy Isolation & Native Batch Ingestion via immich-go | Accepted |
| [ADR-0024](0024-pascal-gpu-lxc-passthrough-docker-container.md) | 2026-10-05 | Hardware / GPU | Pascal GPU LXC Passthrough, Docker Container Toolkit Configuration & Workload Acceleration (Jellyfin NVENC + Immich ML CUDA) | Accepted |
| [ADR-0023](0023-nvidia-geforce-gtx-1080-ti-production.md) | 2026-10-05 | Hardware / GPU | NVIDIA GeForce GTX 1080 Ti Production Driver Deployment & Proxmox Kernel 6.17 DRM Stabilization | Accepted |
| [ADR-0022](0022-authelia-oidc-single-sign-on-federation.md) | 2026-10-05 | Networking / VPN | Authelia OIDC Single Sign-On Federation for Immich & In-Cluster TLS Trust | Accepted |
| [ADR-0021](0021-immich-photo-management-stack-provisioning-external.md) | 2026-10-05 | Networking / VPN | Immich Photo Management Stack Provisioning, External Library Mounting & GitOps Skill Codification | Accepted |
| [ADR-0020](0020-server-side-google-drive-photo-ingestion.md) | 2026-10-04 | Storage & Backup | Server-Side Google Drive Photo Ingestion & Backrest Family Photos Backup Plan | Accepted |
| [ADR-0019](0019-multi-endpoint-restic-orchestration-zero-knowledge.md) | 2026-10-04 | Media & Applications | Multi-Endpoint Restic Orchestration & Zero-Knowledge Server State Backups | Accepted |
| [ADR-0018](0018-backrest-backup-orchestrator-provisioning-caddy-route.md) | 2026-10-04 | Storage & Backup | Backrest Backup Orchestrator Provisioning, Caddy Route & Admin Access Control | Accepted |
| [ADR-0017](0017-lldap-identity-provider-provisioning-gitops-deploy.md) | 2026-10-03 | Media & Applications | LLDAP Identity Provider Provisioning, GitOps Deploy Key & Authelia Backend Cutover | Accepted |
| [ADR-0016](0016-homelab-gitops-architecture-identity-federation-foundation.md) | 2026-10-03 | Networking / VPN | Homelab GitOps Architecture & Identity Federation Foundation | Accepted |
| [ADR-0015](0015-homepage-dashboard-uptime-kuma-24-7.md) | 2026-09-20 | Media & Applications | Homepage Dashboard ("Dixon Fleet") & Uptime Kuma 24/7 Monitoring Deployment | Accepted |
| [ADR-0014](0014-mobile-road-warrior-client-provisioning-split.md) | 2026-09-20 | Networking / VPN | Mobile Road-Warrior Client Provisioning (`10.10.0.5/32`) & Split-Tunneling | Accepted |
| [ADR-0013](0013-wireguard-endpoint-role-reversal-to-ben.md) | 2026-09-20 | Networking / VPN | WireGuard Endpoint Role Reversal to Ben Dedicated Static IPv4 (`157.85.240.10:51820`) | Accepted |
| [ADR-0012](0012-home-assistant-os-virtual-machine-provisioning.md) | 2026-09-20 | Hardware / GPU | Home Assistant OS (HAOS) Virtual Machine (VM 940) Provisioning & Hybrid Smart Home Architecture | Accepted |
| [ADR-0011](0011-dynamic-wireguard-endpoint-migration-dns-resolver.md) | 2026-09-13 | Networking / VPN | Dynamic WireGuard Endpoint Migration (`maslen.id.au`) & DNS Resolver Remediation | Accepted |
| [ADR-0010](0010-audiobookshelf-audiobook-podcast-server-deployment-on.md) | 2026-09-07 | Networking / VPN | Audiobookshelf Audiobook & Podcast Server Deployment on LXC 920 | Accepted |
| [ADR-0009](0009-jellyfin-openid-connect-single-sign-on.md) | 2026-09-07 | Networking / VPN | Jellyfin OpenID Connect (OIDC) Single Sign-On Integration via Authelia | Accepted |
| [ADR-0008](0008-revocation-of-root-ssh-on-lxc.md) | 2026-09-07 | Security & Identity | Revocation of Root SSH on LXC 920 and Deployment of Least-Privilege Read-Only Auditor (`services-agent`) | Accepted |
| [ADR-0007](0007-filebrowser-web-manager-adguard-home-local.md) | 2026-09-07 | Networking / VPN | FileBrowser Web Manager, AdGuard Home Local DNS, and `*.dixon.home` Dual-Stack Routing | Accepted |
| [ADR-0006](0006-dedicated-htpc-service-account-and-isolated.md) | 2026-09-06 | Media & Applications | Dedicated HTPC Service Account and Isolated [Media] Samba Share | Accepted |
| [ADR-0005](0005-media-applications-deployment-on-lxc-920.md) | 2026-09-06 | Media & Applications | Media Applications Deployment (Jellyfin & Calibre-Web) on LXC 920 | Accepted |
| [ADR-0004](0004-dedicated-docker-services-container-reverse-proxy.md) | 2026-09-06 | Networking / VPN | Dedicated Docker Services Container (LXC 920), Reverse Proxy Gateway, and Authelia SSO Portal | Accepted |
| [ADR-0003](0003-multi-device-btrfs-raid1-pool-windows.md) | 2026-09-06 | Storage & Backup | Multi-Device Btrfs RAID1 Pool, Windows-Optimized Samba Share, and AGY Host Runtime | Accepted |
| [ADR-0002](0002-wireguard-boot-persistence-cross-subnet-gateway.md) | 2026-09-06 | Networking / VPN | WireGuard Boot Persistence & Cross-Subnet Gateway Routing | Accepted |
| [ADR-0001](0001-dedicated-read-only-service-account-for.md) | 2026-09-06 | Networking / VPN | Dedicated Read-Only Service Account (`agy-auditor`) for Agent Telemetry | Accepted |

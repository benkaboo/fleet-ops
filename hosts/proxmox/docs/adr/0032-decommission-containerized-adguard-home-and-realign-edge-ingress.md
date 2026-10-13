---
id: ADR-0032
title: Decommission Containerized AdGuard Home & Realign Edge Ingress to Flint 2 Gateway
date: 2026-10-13
status: Accepted
component: Networking & Ingress
tags: [adguard, caddy, homepage, dns, flint2, ingress, gitops]
---

# ADR-0032: Decommission Containerized AdGuard Home & Realign Edge Ingress to Flint 2 Gateway

* **Status:** Accepted
* **Date:** 2026-10-13
* **Component:** Networking & Ingress
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Perimeter DNS Consolidation:** Following the deployment of the GL.iNet Flint 2 router (GL-MT6000, ADR-0001), primary DNS resolution, upstream DoH forwarding, and authoritative homelab rewrites (`*.dixon.home` -> `192.168.68.175`) were migrated natively onto the hardware perimeter gateway at `192.168.68.1:53`.
2. **Elimination of Circular Failure Domain:** Running AdGuard Home inside a container on LXC 920 introduced a single point of failure: any physical link disruption, host reboot, or container lockup on `rath15nas` took down DNS resolution across the entire household. Running AdGuard directly on the router decoupled internet availability from server uptime.
3. **Stale Ingress & Dashboard Drift:** Although the container `adguard` on LXC 920 was decommissioned, Caddy's ingress configuration (`caddy/Caddyfile`) still reverse-proxied `adguard.dixon.home` to `adguard:80`, and the Homepage dashboard (`homepage/config/services.yaml`) monitored `container: adguard` via Docker socket, causing a persistent false "offline" alert.

---

## Action
1. **Edge Ingress Route Cleanup (`caddy/Caddyfile`):**
   * Removed stale `adguard.dixon.home` and `adguard.192.168.68.175.nip.io` reverse proxy definitions targeting `adguard:80`.
2. **Dashboard Synchronization (`homepage/config/services.yaml`):**
   * Removed container health monitoring parameters (`server: my-docker`, `container: adguard`).
   * Updated AdGuard Home tile to point directly to the Flint 2 router dashboard (`http://192.168.68.1:3000`) with description `Perimeter DNS & Ad-Blocking (Flint 2)`.
3. **GitOps Deployment & Verification:**
   * Committed and pushed changes to `benkaboo/homelab-stacks` (`68caf89`).
   * Pulled repository updates onto LXC 920 (`/opt/stacks`).
   * Restarted `caddy` and `homepage` containers (`docker compose restart`).
   * Verified `https://home.dixon.home` returns HTTP 200 OK with zero false-offline indicators.

---

## Consequences
* **Positive:** Complete elimination of circular dependencies: household DNS remains 100% operational regardless of server maintenance, reboots, or container recreation.
* **Positive:** Homepage reflects true operational topology with zero orphaned Docker container probes.
* **Operational:** AdGuard Home management is accessed directly at the perimeter router gateway (`http://192.168.68.1:3000` or `https://console.gl-inet.com`).

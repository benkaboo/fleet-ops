# Incident Log & Problem Management

This document tracks operational incidents, outages, investigations, and resolutions across the `rath15nas` Proxmox infrastructure and interconnected network services.

---

## Incident Register

| Incident ID | Date | Severity | Affected Service | Impact | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **INC-20261006-01** | 2026-10-06 | Critical | Intel I217-V NIC (`nic0` / `e1000e`) | Total Layer 2 network loss to hypervisor and all hosted containers | Resolved (Mitigation in Progress) |
| **INC-20260919-01** | 2026-09-19 | High | WireGuard (`wg-quick@wg0`) | Site-to-site VPN tunnel down due to peer loss of static IP / IPv4 DNS | Resolved |
| **INC-20260913-01** | 2026-09-13 | Medium | WireGuard (`wg-quick@wg0`) | Site-to-site VPN tunnel down after peer ISP WAN IP migration | Resolved |
| **INC-20260906-01** | 2026-09-06 | High | WireGuard (`wg-quick@wg0`) | Site-to-site VPN tunnel down; peer unreachable | Resolved |

---

## Detailed Incident Reports

### INC-20261006-01: Intel I217-V Hardware Unit Hang & Total Fleet Network Outage

* **Incident ID:** `INC-20261006-01`
* **Date & Detection Time:** 2026-10-06 07:17:09 AEST
* **Failure Inception:** 2026-10-05 ~21:50:00 AEST (detected via HTPC backup timeout at 22:00:02 AEST)
* **Reported By:** User / Operator (Ben Maslen)
* **Affected Components:** Physical NIC `nic0` (Intel I217-V, `8086:153B`), Linux bridge `vmbr0`, Proxmox Web GUI, Samba (`simba`), LXC 920 (`services`), VM 940 (`haos`), WireGuard (`wg0`)
* **Status:** Resolved (Physical link reset executed; application workload regulation applied to Immich; standard Linux hardware watchdog daemon staged)

#### 1. Symptom & Triage
* **Reported Behavior:** Total loss of connectivity to Proxmox hypervisor (`192.168.68.169`) and all hosted guest services (`*.dixon.home`). Mapped Samba drives disconnected.
* **Triage Steps:**
  1. Ping tests to `192.168.68.169`, `192.168.68.175`, `192.168.68.170` failed with 100% loss. Router (`192.168.68.1`) and HTPC (`192.168.68.30`) were healthy.
  2. Querying HTPC's `C:\ProgramData\restic\backup.log` pinned failure inception to ~21:50–22:00 AEST on 2026-10-05 (`dial tcp 192.168.68.175:8000: connectex timeout`).
  3. Neighbor inspection on HTPC showed `192.168.68.169` (`74-D0-2B-C5-D7-25`) marked as `Unreachable`.
  4. Physical cable re-seat restored Layer 2 frames immediately.
  5. Post-recovery telemetry confirmed host uptime of **15 hours 31 minutes** (host never crashed or rebooted).

#### 2. Root Cause Analysis
* **Device Identification:** The onboard NIC is an Intel Ethernet Connection I217-V (`PCI_ID=8086:153B`, driver `e1000e`).
* **Silicon Defect:** Interface error telemetry revealed `315,209 missed packets` at the ring buffer. Under sustained high-throughput burst traffic (concurrence of 116 GB / 35,000 photo ingestion via `immich-go`, unthrottled BullMQ background GPU AI indexing, and HTPC restic backups), the Intel I217-V hardware DMA ring descriptor engine deadlocked.
* **Failure Mode:** The PHY link LED stayed lit and Linux reported `state UP`, but the controller ceased passing Layer 2 frames. Re-seating the cable flapped PHY voltage, forcing `e1000e` to reset its descriptor rings.

#### 3. Action & Remediation Plan
1. **Application-Layer Workload Regulation:**
   * Updated [`homelab-stacks/immich/compose.yaml`](file:///C:/Users/benma/coding/agy_project/Projects/homelab-stacks/immich/compose.yaml) to declare CPU quotas (`cpus: '2.5'` for server, `cpus: '2.0'` for machine learning) and 4 GB memory limits.
   * Regulated Immich Job Settings worker concurrency down to 1 worker per AI queue.
2. **Watchdog Daemon Provisioning:**
   * Authored [`scripts/setup-network-watchdog.sh`](scripts/setup-network-watchdog.sh) and [`scripts/deploy-network-watchdog.ps1`](scripts/deploy-network-watchdog.ps1) deploying Debian standard `watchdog` daemon.
   * Configured `/etc/watchdog.conf` with `interface = nic0` and `ping = 192.168.68.1`.
   * Installed self-healing script `/usr/local/bin/nic0-repair.sh` to auto-cycle `nic0` (down/up) upon 3 failed probes, resolving future DMA stalls in software within 30 seconds without requiring physical cable re-seats.

#### 4. Prevention & Lessons Learned
* **Legacy Silicon Sensitivity:** Haswell-era Intel I217-V NICs cannot absorb unthrottled multi-container virtual bridge bursts without descriptor oversubscription.
* **Self-Healing Watchdogs:** Standard POSIX/Linux watchdog daemons paired with targeted repair scripts convert potentially hours-long physical intervention outages into sub-minute, zero-touch automated recoveries.

### INC-20260919-01: WireGuard Tunnel Outage due to Peer Static IP Deprecation (Resolved via Role Reversal)

* **Incident ID:** `INC-20260919-01`
* **Date & Detection Time:** 2026-09-19 10:34:37 AEST
* **Failure Inception:** ~2026-09-17 18:00 AEST (last active handshake ~1.7 days prior)
* **Reported By:** User / Remote Peer Operator (Brother)
* **Affected Components:** `wg-quick@wg0.service`, interface `wg0`, cross-subnet routing to `192.168.6.0/24`
* **Status:** Resolved (Reversed topology roles: `rath15nas` configured as inbound listener on port `51820` behind Neptune static IPv4 `157.85.240.10`; Deco M9 port forward activated; remote peer reconfigured to connect outbound; tunnel up, handshakes active, peer pingable)

#### 1. Symptom & Triage
* **Reported Behavior:** Remote peer lost static IP. Host `rath15nas` could not establish handshake with remote endpoint (`maslen.id.au:51820`). Pings to `10.10.0.1` and `192.168.6.1` failed.
* **Triage Steps:**
  1. Inspected DNS resolution for `maslen.id.au`: Domain only returned an IPv6 `AAAA` record (`2401:d002:b504:3300::1`), with no public IPv4 `A` record.
  2. Inspected `rath15nas` WireGuard interface: `sudo wg show wg0` confirmed last handshake was 1 day, 17 hours ago.
  3. Validated local WAN connectivity: Verified Ben's public IP `157.85.240.10` is a dedicated static IPv4 with Neptune Internet (`AS151660`, PTR `ip-157.85.240.10.neptune.net.au`).

#### 2. Root Cause Analysis
* The remote peer lost its public static IPv4 address, leaving no routable IPv4 endpoint for `rath15nas` to initiate connections to.
* In WireGuard's peer-to-peer cryptographic routing model, only one peer needs a static public IP and port forward, while the other can roam behind dynamic IPs or CGNAT using keepalive packets.

#### 3. Action & Remediation Plan
1. **Automation Script:** Developed [`scripts/reconfigure-wireguard-listener.sh`](scripts/reconfigure-wireguard-listener.sh) and [`scripts/deploy-wireguard-listener.ps1`](scripts/deploy-wireguard-listener.ps1).
2. **Proxmox Host Reconfiguration:**
   * Updated `/etc/wireguard/wg0.conf` to set `ListenPort = 51820` under `[Interface]`.
   * Removed stale outbound `Endpoint = maslen.id.au:51820` under `[Peer]`.
   * Restarted `wg-quick@wg0.service`.
3. **Gateway NAT Forwarding:**
   * Added UDP port forward on TP-Link Deco M9 (`192.168.68.1`): External `51820/UDP` $\rightarrow$ `192.168.68.169:51820`.
4. **Peer Configuration Update:**
   * Remote peer configured Ben's endpoint as `Endpoint = 157.85.240.10:51820` with `PersistentKeepalive = 25`.
5. **Validation:**
   * Handshake established successfully (`rath15nas` dynamically learned peer roaming endpoint `115.70.61.168:50284`).
   * ICMP ping to `10.10.0.1` succeeded (0% loss, ~19ms latency).
   * ICMP ping to `192.168.6.1` succeeded from both `rath15nas` (~19ms) and Windows workstation (~26ms).

#### 4. Prevention & Lessons Learned
* **Asymmetric NAT Topology:** When one party possesses a guaranteed static public IPv4 and the other is subject to residential dynamic IP / CGNAT reallocation, the peer with the static IP should always act as the listening hub endpoint.
* **Keepalive Resilience:** Outbound `PersistentKeepalive = 25` on the roaming dynamic peer preserves stateful firewall pinholes across ISP IP shifts.

### INC-20260913-01: WireGuard Tunnel Outage due to Peer ISP Migration & Stale Host DNS

* **Incident ID:** `INC-20260913-01`
* **Date & Detection Time:** 2026-09-13 17:01:08 AEST
* **Failure Inception:** Following remote peer ISP migration
* **Reported By:** User / Remote Peer Operator (Brother)
* **Affected Components:** `wg-quick@wg0.service`, interface `wg0`, cross-subnet routing to `192.168.6.0/24`
* **Status:** Resolved (Endpoint migrated to dynamic hostname `maslen.id.au:51820`; `/etc/resolv.conf` updated with redundant resolvers; tunnel up and peer pingable)

#### 1. Symptom & Triage
* **Reported Behavior:** Remote peer changed ISP, changing public endpoint IP. Pings across tunnel from `rath15nas` to `10.10.0.1` failed with 100% packet loss.
* **Triage Steps:**
  1. Validated reachability to remote peer's new public IP `157.85.240.12`: ICMP ping succeeded with 0% loss (~20–47ms latency).
  2. Discovered host DNS failure: `/etc/resolv.conf` pointed to deprecated Superloop resolver `119.40.106.35`, which returned `REFUSED` on all hostname lookups including `maslen.id.au`.
  3. Confirmed `/etc/wireguard/wg0.conf` contained hardcoded deprecated IP `203.132.95.12:51820`.

#### 2. Root Cause Analysis
1. Peer WAN IP changed from `203.132.95.12` to `157.85.240.12`. WireGuard will not auto-discover the new IP when the endpoint is hardcoded as an IP address in `wg0.conf`.
2. Stale DNS configuration on `rath15nas` prevented resolving the dynamic DNS domain `maslen.id.au`.

#### 3. Action & Remediation Plan
1. Created automated remediation scripts [`scripts/update-wireguard-endpoint.sh`](scripts/update-wireguard-endpoint.sh) and [`scripts/update-wireguard-endpoint.ps1`](scripts/update-wireguard-endpoint.ps1).
2. Updated `/etc/resolv.conf` to add local router gateway `192.168.68.1` and `1.1.1.1`.
3. Updated `/etc/wireguard/wg0.conf` to configure `Endpoint = maslen.id.au:51820`.
4. Restarted `wg-quick@wg0.service`.
5. Verified tunnel state and reachability to `10.10.0.1` (~19ms) and `192.168.6.1` (~22ms).

#### 4. Prevention & Lessons Learned
* **FQDN Endpoints:** Always use dynamic DNS hostnames (FQDNs) rather than hardcoded public IPs for WireGuard endpoints where WAN IPs are subject to ISP reassignment.
* **Resilient Host Resolvers:** Ensure hypervisor `/etc/resolv.conf` includes the local LAN gateway (`192.168.68.1`) and public fallback resolvers (`1.1.1.1`) rather than provider-specific DNS IPs that fail across ISP switches.

### INC-20260906-01: WireGuard Boot Failure due to Malformed Whitespace in `wg0.conf`

* **Incident ID:** `INC-20260906-01`
* **Date & Detection Time:** 2026-09-06 16:35:26 AEST
* **Failure Inception:** 2026-09-06 14:59:43 AEST (following system reboot)
* **Reported By:** User / Remote Peer Operator (Brother)
* **Affected Components:** `wg-quick@wg0.service`, interface `wg0`, routing to `10.10.0.0/24` and `192.168.6.0/24`
* **Status:** Resolved (Remediated via `scripts/repair-wireguard-config.sh`; interface up, handshakes active, peer pingable)

#### 1. Symptom & Triage
* **Reported Behavior:** Remote peer reported WireGuard connection failure. Pings from `rath15nas` to peer address `10.10.0.1` failed with 100% packet loss.
* **Triage Steps:**
  1. Verified physical WAN connectivity: ICMP ping to remote endpoint `203.132.95.12` succeeded (0% loss, ~36ms latency). Network route is healthy.
  2. Inspected WireGuard interface: `wg show` returned `Device "wg0" does not exist`.
  3. Inspected systemd service: `systemctl status wg-quick@wg0.service` showed state `failed (Result: exit-code)` since `Sun 2026-09-06 14:59:43 AEST`.

#### 2. Root Cause Analysis
During host startup at 14:59:43 AEST, `wg-quick@wg0.service` executed `wg setconf wg0` and attempted to process lifecycle hooks in `/etc/wireguard/wg0.conf`. The service crashed with the following error:

```text
wg-quick[1182]: Line unrecognized: `PostUp=iptables-tnat-APOSTROUTING-o%i-jMASQUERADE;iptables-AFORWARD-o%i-d192.168.6.0/24-jACCEPT;iptables-AFORWARD-i%i-mconntrack--ctstateRELATED,ESTABLISHED-jACCEPT'
wg-quick[1182]: Configuration parsing error
wg-quick[1138]: [#] ip link delete dev wg0
systemd[1]: wg-quick@wg0.service: Main process exited, code=exited, status=1/FAILURE
```

* **Root Cause:** When `PostUp` and `PostDown` firewall rules were persisted into `/etc/wireguard/wg0.conf`, all internal whitespace was stripped out (likely due to unquoted subshell evaluation or space-collapsing echo). 
* Because `wg-quick` parses commands by splitting tokens on spaces, command strings like `iptables-tnat-APOSTROUTING` failed lexical analysis. 
* Under `wg-quick` error handling, any failure in `PostUp` triggers an immediate rollback (`ip link delete dev wg0`), leaving the interface offline.

#### 3. Action & Remediation Plan
1. **Develop Automated Remediation Script:** Created [`scripts/repair-wireguard-config.sh`](scripts/repair-wireguard-config.sh).
2. **Configuration Backup:** Create a timestamped backup copy at `/etc/wireguard/wg0.conf.bak.<timestamp>`.
3. **Configuration Sanitization:** Purge corrupted `PostUp=iptables-*` and `PostDown=iptables-*` lines from `/etc/wireguard/wg0.conf`.
4. **Hook Restoration:** Append properly tokenized directives:
   ```ini
   PostUp = iptables -t nat -A POSTROUTING -o %i -j MASQUERADE; iptables -A FORWARD -o %i -d 192.168.6.0/24 -j ACCEPT; iptables -A FORWARD -i %i -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
   PostDown = iptables -t nat -D POSTROUTING -o %i -j MASQUERADE; iptables -D FORWARD -o %i -d 192.168.6.0/24 -j ACCEPT; iptables -D FORWARD -i %i -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
   ```
5. **Service Recovery:** Restart `wg-quick@wg0.service`.
6. **Connectivity Verification:**
   * Validate interface state (`wg show`).
   * Verify peer handshake and packet transfer counters.
   * Verify end-to-end ping to `10.10.0.1`.

#### 4. Prevention & Lessons Learned
* **Configuration Syntax Checking:** Configuration files generated or amended via scripts must undergo syntax validation (e.g. `bash -n` or dry-run parsing) before service reload.
* **Quoting Discipline:** Prevent space-stripping by strictly using quoted EOF heredocs (`cat << 'EOF'`) when injecting multi-token rules into configuration files.

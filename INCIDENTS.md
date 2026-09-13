# Incident Log & Problem Management

This document tracks operational incidents, outages, investigations, and resolutions across the `rath15nas` Proxmox infrastructure and interconnected network services.

---

## Incident Register

| Incident ID | Date | Severity | Affected Service | Impact | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **INC-20260913-01** | 2026-09-13 | Medium | WireGuard (`wg-quick@wg0`) | Site-to-site VPN tunnel down after peer ISP WAN IP migration | Resolved |
| **INC-20260906-01** | 2026-09-06 | High | WireGuard (`wg-quick@wg0`) | Site-to-site VPN tunnel down; peer unreachable | Resolved |

---

## Detailed Incident Reports

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

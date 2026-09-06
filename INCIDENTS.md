# Incident Log & Problem Management

This document tracks operational incidents, outages, investigations, and resolutions across the `rath15nas` Proxmox infrastructure and interconnected network services.

---

## Incident Register

| Incident ID | Date | Severity | Affected Service | Impact | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **INC-20260906-01** | 2026-09-06 | High | WireGuard (`wg-quick@wg0`) | Site-to-site VPN tunnel down; peer unreachable | Resolved |

---

## Detailed Incident Reports

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

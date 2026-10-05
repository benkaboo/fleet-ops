# Router Configurations & Backups (`hosts/router/configs`)

Store exported configuration backups for the primary router here (e.g. `.json`, `.xml`, `.conf`, or `.rsc` files).

---

## ⚠️ Sanitization Checklist (Rule 4: Zero Secret Leakage)

Before committing any router backup file to version control, verify that:
* [ ] PPPoE / ISP connection usernames and passwords have been redacted.
* [ ] Pre-shared Wi-Fi keys (WPA2/WPA3 passwords) have been replaced with `<WIFI_PSK_IN_VAULT>`.
* [ ] WireGuard private keys / interface keys have been redacted.
* [ ] Admin Web UI passwords or password hashes have been removed.

Store raw passwords exclusively in Bitwarden / 1Password under `Homelab Router Admin`.

# ADR-0009: Jellyfin OpenID Connect (OIDC) Single Sign-On Integration via Authelia

* **Status:** Accepted
* **Date:** 2026-09-07
* **Component:** Networking / VPN
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Application-Level Authentication vs Reverse Proxy Forward-Auth:**
   * Living-room streaming devices, specifically the Sony Android TV client and mobile Jellyfin apps, break when HTTP reverse-proxy forward-auth (`import authelia-auth`) is placed in front of the Jellyfin endpoint. Client apps do not handle HTTP 302 redirects to web login forms or interactive 2FA portals, and Jellyfin's native Quick Connect mechanism requires unintercepted direct API access.
   * Single Sign-On (SSO) was required for browser-based users without compromising direct API access, Quick Connect, or hardware playback for dedicated smart TV clients.
2. **Container Networking & PKI Trust Store Constraints:**
   * Docker containers on internal bridges inside LXC 920 do not resolve LAN domains like `auth.dixon.home` via the local subnet gateway router (`192.168.68.1`).
   * Caddy's internal automated TLS (`tls internal`) issues self-signed CA certificates that are not trusted by default inside .NET runtime environments (Jellyfin), producing `PartialChain` certificate validation failures when making backend OIDC discovery requests to `https://auth.dixon.home/.well-known/openid-configuration`.
3. **OIDC Client & Protocol Quirks:**
   * `jellyfin-plugin-sso` (v4.0.0.4) implements Pushed Authorization Requests (PAR) using `client_secret_basic` but exchanges authorization codes at the token endpoint via `client_secret_post`, resulting in client authentication mismatches if PAR is enforced.
   * The plugin's role claim parser expects discrete role claims; comma-concatenating allowed groups within a single XML element causes authentication rejections.

## Action
1. **Authelia OIDC Provider & Secret Injection (`configuration.yml` & `compose.yaml`):**
   * Generated dedicated 4096-bit RSA signing key (`/opt/stacks/authelia/config/oidc.key`) with restricted permissions (`chmod 600`).
   * Registered OIDC client `jellyfin` supporting `client_secret_post` authorization code flow targeting redirect URI `https://jellyfin.dixon.home/sso/OID/redirect/authelia`.
   * Declared `X_AUTHELIA_CONFIG_FILTERS=template` in `compose.yaml` to dynamically inject file-based secrets via `{{ secret "/config/oidc.key" | mindent 10 "|" | msquote }}` without exposing raw key contents in version control.
2. **Internal DNS & TLS Trust Store Mounting:**
   * Added `extra_hosts: ["auth.dixon.home:192.168.68.175"]` to `/opt/stacks/jellyfin/compose.yaml` for instantaneous container-to-container DNS resolution.
   * Extracted Caddy's internal root certificate authority (`caddy.crt`) to the host trust store (`/usr/local/share/ca-certificates/`) and executed `update-ca-certificates`.
   * Mounted the updated certificate bundle into Jellyfin as `/etc/ssl/certs/ca-certificates.crt:ro`.
3. **Jellyfin SSO Plugin Configuration (`SSO-Auth.xml`):**
   * Configured `SSO-Auth` plugin (v4.0.0.4) with Authelia OpenID endpoints.
   * Set `<DisablePushedAuthorization>true</DisablePushedAuthorization>` to bypass PAR and maintain protocol consistency on `client_secret_post`.
   * Set `<EnableAuthorization>false</EnableAuthorization>` to delegate access gatekeeping to Authelia while assigning administrator privileges via `<AdminRoles><string>admins</string></AdminRoles>`.
4. **Live Verification:**
   * Confirmed user `bjm` (`Ben Maslen`) authenticated via SSO with full administrative and transcoding policies applied.
   * Validated live media playback (HLS transcoding via Jellyfin FFmpeg) and verified zero regressions for direct TV streaming and Quick Connect.

## Consequences
* **Positive:** Centralized single sign-on authentication for Jellyfin web sessions using unified homelab Authelia credentials.
* **Positive:** Native smart TV apps, Android TV, Quick Connect, and mobile streaming clients remain completely functional without HTTP 302 redirect collisions.
* **Positive:** Automated mapping of Authelia `admins` group to Jellyfin administrative privileges.
* **Security:** Private keys and client secrets are maintained with strict filesystem permissions (`chmod 600`) and isolated from Git repositories.

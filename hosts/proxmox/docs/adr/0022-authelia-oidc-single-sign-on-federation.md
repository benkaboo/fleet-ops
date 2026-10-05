# ADR-0022: Authelia OIDC Single Sign-On Federation for Immich & In-Cluster TLS Trust

* **Status:** Accepted
* **Date:** 2026-10-05
* **Component:** Networking / VPN
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Single Sign-On (SSO) Unification:** Following the deployment of the Immich photo management stack, the operator required federated authentication against the centralized homelab identity system (Authelia backed by LLDAP directory `dc=home,dc=arpa`). This enables family members to authenticate seamlessly across both desktop browsers and native mobile apps without maintaining separate local passwords.
2. **Backchannel Token Verification & Internal PKI Trust:** Immich is a Node.js/NestJS service running inside a container. Node.js relies on an internal, hardcoded Mozilla root CA bundle and does not consult host system trust stores by default. Because Caddy terminates HTTPS using internal PKI (`tls internal`), backchannel OIDC discovery and authorization code/token exchanges between `immich-server` and `auth.dixon.home` failed with TLS local issuer errors and NXDOMAIN lookups.
3. **Decoupled Secret Discipline & GitOps:** In accordance with the GitOps decoupled secret pattern, client registration must be committed to the declarative repository (`benkaboo/homelab-stacks`) using template expansion (`HOMELAB_IMMICH_CLIENT_SECRET`), while the one-way PBKDF2 hash is hydrated directly into `/opt/stacks/authelia/.env` on LXC 920.

## Action
1. **Authelia Client Registration (`benkaboo/homelab-stacks`):**
   * Configured client `immich` in `authelia/config/configuration.yml` with `authorization_policy: one_factor`, `client_secret_post`, and redirect URIs supporting desktop and mobile deep links (`app.immich:///oauth-callback`, `https://photos.dixon.home/api/oauth/mobile-redirect`, `https://photos.dixon.home/auth/login`, and `.nip.io` variants).
   * Updated `authelia/authelia.env.example` template with `HOMELAB_IMMICH_CLIENT_SECRET`.
   * Committed and pushed to GitHub (`0058fdb`).
2. **Runtime Secret Hydration on LXC 920:**
   * Pulled updates on LXC 920 (`/opt/stacks`).
   * Backed up `/opt/stacks/authelia/.env` to `.env.bak`.
   * Generated 32-character random client secret and calculated the PBKDF2 digest using Authelia's crypto engine (`docker exec authelia authelia crypto hash generate pbkdf2`).
   * Appended `HOMELAB_IMMICH_CLIENT_SECRET` to `/opt/stacks/authelia/.env` and recreated Authelia container (`docker compose up -d --force-recreate authelia`).
3. **In-Cluster TLS Trust & Host Resolution (`immich/compose.yaml`):**
   * Updated `immich/compose.yaml` with `extra_hosts` mapping `auth.dixon.home:192.168.68.175`.
   * Mounted host CA bundle `/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro`.
   * Injected environment variable `NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt` so Node.js trusts Caddy's internal root CA.
   * Committed to GitHub (`4cdf97c`), pulled on host, and recreated `immich_server`.
4. **Health & Endpoint Verification:**
   * Verified OIDC discovery endpoint `https://auth.dixon.home/.well-known/openid-configuration` returns HTTP 200 from both host and from inside `immich_server` with zero TLS verification or DNS errors.
   * Verified Caddy ingress HTTP 200 for both `auth` and `photos` services.
   * Synchronized updates to `ARCHITECTURE.md`.

## Consequences
* **Positive:** Immich users can now authenticate via Authelia SSO across both desktop web and mobile clients.
* **Positive:** Backchannel OIDC token exchanges succeed natively over internal HTTPS without disabling TLS verification or relying on external DNS.
* **Positive:** Strict GitOps secret decoupling maintained: no plain or hashed secrets committed to version control; plaintext client secret secured in operator password vault (Bitwarden).
* **Operational:** Auto-registration enabled in Immich OAuth allows family accounts in LLDAP (`group: family`) to automatically provision Immich accounts upon first successful SSO login.

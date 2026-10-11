---
id: ADR-0030
title: Audiobookshelf Authelia OpenID Connect (OIDC) Single Sign-On Integration & In-Cluster TLS Trust
date: 2026-10-11
status: Accepted
component: Identity & Security
tags: [audiobookshelf, authelia, oidc, sso, lldap, pki, caddy, gitops]
---

# ADR-0030: Audiobookshelf Authelia OpenID Connect (OIDC) Single Sign-On Integration & In-Cluster TLS Trust

* **Status:** Accepted
* **Date:** 2026-10-11
* **Component:** Identity & Security
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **Centralized Identity Federation:** Audiobookshelf (v2.36.0) was previously operating with standalone local authentication. The operator required federated Single Sign-On (SSO) integrated with the centralized homelab identity system (Authelia backed by the LLDAP directory `dc=home,dc=arpa`), enabling unified account management across web browsers and native mobile applications.
2. **Backchannel Token Verification & Internal PKI Trust:** Audiobookshelf is a Node.js service running inside a container. Node.js relies on an internal Mozilla root CA bundle and does not consult host trust stores by default. Because Caddy terminates HTTPS using internal PKI (`tls internal`), backchannel OIDC discovery and authorization code/token exchanges between Audiobookshelf and `https://auth.dixon.home` failed with TLS certificate verification errors (`0A000086:certificate verify failed`).
3. **Decoupled Secret Discipline & GitOps:** In accordance with homelab GitOps standards, client registration must be committed to `benkaboo/homelab-stacks` using template expansion (`HOMELAB_AUDIOBOOKSHELF_CLIENT_SECRET`), while the one-way PBKDF2 digest is hydrated directly into `/opt/stacks/authelia/.env` on LXC 920.

## Action
1. **Authelia Client Registration (`benkaboo/homelab-stacks`):**
   * Configured client `audiobookshelf` in `authelia/config/configuration.yml` with `authorization_policy: one_factor`, `require_pkce: true`, `pkce_challenge_method: S256`, `token_endpoint_auth_method: client_secret_basic`, and redirect URIs (`https://audiobooks.dixon.home/auth/openid/callback`, `https://audiobooks.dixon.home/auth/openid/mobile-redirect`, and `audiobookshelf://oauth`).
   * Updated `authelia/authelia.env.example` template with `HOMELAB_AUDIOBOOKSHELF_CLIENT_SECRET`.
2. **In-Cluster TLS Trust & Host Resolution (`audiobookshelf/compose.yaml`):**
   * Added `extra_hosts` mapping `auth.dixon.home:192.168.68.175`.
   * Mounted host CA bundle `/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro`.
   * Injected environment variable `NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt` so Node.js trusts Caddy's internal root CA.
   * Committed and pushed to GitHub (`77e1567`).
3. **Runtime Secret Hydration & Deployment on LXC 920:**
   * Pulled updates on LXC 920 (`/opt/stacks`).
   * Generated 32-character high-entropy client secret and calculated the PBKDF2 digest using Authelia's crypto engine (`docker exec authelia authelia crypto hash generate pbkdf2 --random --random.length 32`).
   * Backed up `/opt/stacks/authelia/.env` to `.env.bak` and appended `HOMELAB_AUDIOBOOKSHELF_CLIENT_SECRET`.
   * Recreated `authelia` and `audiobookshelf` containers (`docker compose up -d --force-recreate`).
4. **Health & Endpoint Verification:**
   * Verified OIDC discovery endpoint `https://auth.dixon.home/.well-known/openid-configuration` returns HTTP 200 from inside `audiobookshelf` with zero TLS verification or DNS errors across both `wget` and Node.js `fetch`.
   * Verified container health and clean startup across `authelia` and `audiobookshelf`.

## Consequences
* **Positive:** Audiobookshelf users can authenticate via Authelia SSO across desktop web and mobile clients using standard OpenID Connect 1.0 with PKCE.
* **Positive:** Backchannel OIDC discovery and token exchanges succeed natively over internal HTTPS without disabling TLS verification or relying on external DNS.
* **Positive:** Zero secret leakage in version control; plaintext client secret secured in operator password vault, and only cryptographic digest persisted on host.
* **Operational:** Web GUI settings in Audiobookshelf (Settings -> Authentication) configured with Issuer URL `https://auth.dixon.home` and client secret.

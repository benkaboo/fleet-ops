# ADR-0001: Workstation Audit & Governance Initialization

* **Status:** Accepted
* **Date:** 2026-09-08
* **Component:** Security & Governance
* **Deciders:** Operator (Ben Maslen), Antigravity AI Agent

---

## Context
1. **The Problem / Requirement:** The host machine requires a comprehensive architectural inventory and cautious, non-disruptive cleanup of developer runtimes, caches, and legacy files.
2. **Constraints & Trade-offs:** Zero operational disruption to the workstation; strictly adhere to tiered execution (autonomous read-only inspection, mandatory pre-flight security cards for mutations).

## Action
1. Created dedicated repository at `Projects/Workstation`.
2. Configured workspace boundaries and execution tiers in `AGENTS.md`.
3. Created non-invasive baseline inspection script `scripts/inspect_host.ps1`.

## Consequences
* **Positive:** Isolated audit workspace; inherits global governance rules and changelog discipline from `personal-governance`.
* **Operational:** Maintenance records and system architecture documents will be tracked via Git version control.
* **Security:** Hardened safety boundaries prevent accidental modification of system files or registry keys.

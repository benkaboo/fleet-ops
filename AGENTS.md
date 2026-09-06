# Agent Governance & Documentation Rules

## Operational Workflow
1. **Pre-Flight Inspection:** Before applying any mutating configuration, state change, or network alteration on remote hosts, describe the proposed change and wait for user confirmation.
2. **Decision Prompting:** If a session involves an architectural change, package installation, network/firewall rule change, or permission update:
   - Explicitly prompt the user: "Would you like me to record this decision in CHANGELOG.md and commit the update?"
   - If approved, draft an entry using the Architectural Decision Record (ADR) format (Context, Action, Consequences) in CHANGELOG.md.
3. **Architecture Synchronization:** If interface names, IP ranges, container IDs, or service states change, update ARCHITECTURE.md to reflect reality.
4. **Git Hygiene:** 
   - Never commit sensitive materials (.key, .conf with secrets, .env).
   - Write structured, conventional commit messages (e.g., docs(changelog): record sysctl forwarding change).

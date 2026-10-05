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
5. **Script Execution & Staging Pattern for Sudo Operations (`rath15nas`):**
   - Piping script contents over SSH stdin (`Get-Content | ssh sudo bash`) breaks pseudo-terminal (TTY) allocation because `sudo` requires an interactive terminal to prompt the operator for their password.
   - **Canonical Pattern:**
     1. Stage the script to `/tmp/<script-name>.sh` via `scp`.
     2. Either invoke with interactive TTY (`ssh -t bjm@192.168.68.169 "sudo bash /tmp/<script-name>.sh"`) or have the operator execute `sudo bash /tmp/<script-name>.sh` directly from an active SSH shell on `rath15nas`.
6. **GitOps Deployment Workflow for LXC 920 (`services`):**
   - Stacks on `/opt/stacks` track the private GitOps repository `benkaboo/homelab-stacks`.
   - Never create or edit compose files, reverse proxy rules, or dashboard configs directly on LXC 920 via SSH.
   - Always author changes in `Projects/homelab-stacks`, commit and push to `origin main`, then pull on LXC 920 (`git -C /opt/stacks pull`).
   - Hydrate decoupled runtime `.env` secrets on host from `.env.example`.


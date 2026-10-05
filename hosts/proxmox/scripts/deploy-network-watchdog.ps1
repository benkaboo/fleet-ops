# ==============================================================================
# Deploy Network Watchdog Daemon to Proxmox Host (rath15nas)
# Run directly from PowerShell on your Windows workstation
# ==============================================================================

[CmdletBinding()]
param(
    [string]$RemoteHost = "192.168.68.169",
    [string]$SshUser = "bjm"
)

$ScriptPath = Join-Path $PSScriptRoot "setup-network-watchdog.sh"
$RemoteTmp = "/tmp/setup-network-watchdog.sh"

Clear-Host
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "    Deploy Network Watchdog Daemon to rath15nas ($RemoteHost)" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

if (-not (Test-Path $ScriptPath)) {
    Write-Error "Script not found at: $ScriptPath"
    exit 1
}

Write-Host "[1/2] Transferring script to $RemoteHost:$RemoteTmp via scp..." -ForegroundColor Green
scp "$ScriptPath" "$SshUser@${RemoteHost}:${RemoteTmp}"
ssh "$SshUser@$RemoteHost" "chmod +x $RemoteTmp"

Write-Host "`n[2/2] Executing script interactively on $RemoteHost via SSH..." -ForegroundColor Green
Write-Host "[*] Enter sudo password when prompted:`n" -ForegroundColor Yellow

ssh -t "$SshUser@$RemoteHost" "sudo bash $RemoteTmp; rm -f $RemoteTmp"

Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "    Deployment Completed" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

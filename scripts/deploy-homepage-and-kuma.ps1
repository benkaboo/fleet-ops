# ==============================================================================
# Deploy Homepage Dashboard & Uptime Kuma on Proxmox Host (rath15nas)
# Run directly from PowerShell on your Windows workstation
# ==============================================================================

[CmdletBinding()]
param(
    [string]$RemoteHost = "192.168.68.169",
    [string]$SshUser = "bjm"
)

$ScriptPath = Join-Path $PSScriptRoot "lxc-setup\20-deploy-homepage-and-kuma.sh"
$RemoteTmp = "/tmp/20-deploy-homepage-and-kuma.sh"

Clear-Host
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "    Deploy Homepage Dashboard & Uptime Kuma on rath15nas (LXC 920)" -ForegroundColor Cyan
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

# ==============================================================================
# Repair WireGuard Service & Configuration (INC-20260906-01)
# Run directly from PowerShell on your Windows workstation
# ==============================================================================

[CmdletBinding()]
param(
    [string]$RemoteHost = "192.168.68.169",
    [string]$SshUser = "bjm"
)

$ScriptPath = Join-Path $PSScriptRoot "repair-wireguard-config.sh"
$RemoteTmpPath = "/tmp/repair-wireguard-config.sh"

Clear-Host
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "    WireGuard Service & Config Repair (INC-20260906-01)" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Target: $SshUser@$RemoteHost"
Write-Host "Script: $ScriptPath`n"

if (-not (Test-Path $ScriptPath)) {
    Write-Error "Could not find repair script at: $ScriptPath"
    exit 1
}

Write-Host "[1/2] Transferring repair script to Proxmox (/tmp)..." -ForegroundColor Green
scp $ScriptPath "${SshUser}@${RemoteHost}:${RemoteTmpPath}"

Write-Host "`n[2/2] Running repair script interactively with sudo..." -ForegroundColor Green
Write-Host "[*] Enter sudo password when prompted:`n" -ForegroundColor Yellow

ssh -t "$SshUser@$RemoteHost" "sudo bash $RemoteTmpPath; rm -f $RemoteTmpPath"

Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "    Repair Execution Completed" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

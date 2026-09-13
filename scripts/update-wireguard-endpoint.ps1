# ==============================================================================
# Update WireGuard Remote Endpoint & DNS (New ISP IP)
# Run directly from PowerShell on your Windows workstation
# ==============================================================================

[CmdletBinding()]
param(
    [string]$RemoteHost = "192.168.68.169",
    [string]$SshUser = "bjm"
)

$ScriptPath = Join-Path $PSScriptRoot "update-wireguard-endpoint.sh"
$RemoteTmpPath = "/tmp/update-wireguard-endpoint.sh"

Clear-Host
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "    WireGuard Remote Endpoint & DNS Remediation" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Target: $SshUser@$RemoteHost"
Write-Host "Script: $ScriptPath`n"

if (-not (Test-Path $ScriptPath)) {
    Write-Error "Could not find script at: $ScriptPath"
    exit 1
}

Write-Host "[1/2] Transferring remediation script to Proxmox (/tmp)..." -ForegroundColor Green
scp $ScriptPath "${SshUser}@${RemoteHost}:${RemoteTmpPath}"

Write-Host "`n[2/2] Running remediation script interactively with sudo..." -ForegroundColor Green
Write-Host "[*] Enter sudo password when prompted:`n" -ForegroundColor Yellow

ssh -t "$SshUser@$RemoteHost" "sudo bash $RemoteTmpPath; rm -f $RemoteTmpPath"

Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "    Execution Completed" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

# ==============================================================================
# Decommission Legacy Co-Administrator (dmm)
# Run only AFTER validating that 'dmgm' can successfully authenticate.
# Run directly from PowerShell on your Windows workstation
# ==============================================================================

[CmdletBinding()]
param(
    [string]$RemoteHost = "192.168.68.169",
    [string]$SshUser = "bjm",
    [string]$ScriptPath = ""
)

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $ScriptPath) {
    $ScriptPath = Join-Path $ScriptDir "lxc-setup\17-cleanup-legacy-dmm.sh"
}

Clear-Host
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "    Decommission Legacy Co-Administrator 'dmm' on rath15nas & LXC 920" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

if (-not (Test-Path $ScriptPath)) {
    Write-Error "Script not found at: $ScriptPath"
    exit 1
}

Write-Host "[*] Target Host: $SshUser@$RemoteHost" -ForegroundColor Yellow
Write-Host "[*] Script:      $ScriptPath" -ForegroundColor Yellow
Write-Host ""
Write-Host "WARNING: Run this script ONLY after verifying that 'dmgm' can:" -ForegroundColor Yellow
Write-Host "  * SSH into rath15nas (192.168.68.169 / 10.10.0.4)" -ForegroundColor Yellow
Write-Host "  * Log into the Proxmox Web GUI as dmgm@pam" -ForegroundColor Yellow
Write-Host "  * Log into Authelia as dmgm" -ForegroundColor Yellow
Write-Host ""

$Confirm = Read-Host "Has David validated 'dmgm' and do you want to permanently remove 'dmm'? (Y/n) [n]"
if ($Confirm -notmatch "^[yY]") {
    Write-Host "[-] Cancelled. 'dmm' remains intact." -ForegroundColor Green
    exit 0
}

$RemoteTmp = "/tmp/17-cleanup-legacy-dmm.sh"
Write-Host "`n[*] Staging cleanup script to $RemoteHost:$RemoteTmp via scp..." -ForegroundColor Green
scp -i ~/.ssh/id_ed25519 "$ScriptPath" "$SshUser@$RemoteHost`:$RemoteTmp"
ssh -i ~/.ssh/id_ed25519 "$SshUser@$RemoteHost" "chmod +x $RemoteTmp"

Write-Host "[*] Executing cleanup script interactively on $RemoteHost via SSH..." -ForegroundColor Green
Write-Host "    (You will be prompted for your '$SshUser' sudo password)" -ForegroundColor Yellow
ssh -t -i ~/.ssh/id_ed25519 "$SshUser@$RemoteHost" "sudo bash $RemoteTmp"

Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "    Cleanup finished. 'dmm' has been removed." -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

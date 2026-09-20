# ==============================================================================
# Provision Co-Administrator (dmgm) on Proxmox & LXC 920
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
    $ScriptPath = Join-Path $ScriptDir "lxc-setup\16-setup-dmgm-coadmin.sh"
}

Clear-Host
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "    Provision Co-Administrator 'dmgm' on Proxmox (rath15nas) & LXC 920" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

if (-not (Test-Path $ScriptPath)) {
    Write-Error "Script not found at: $ScriptPath"
    exit 1
}

Write-Host "[*] Target Host: $SshUser@$RemoteHost" -ForegroundColor Yellow
Write-Host "[*] Script:      $ScriptPath" -ForegroundColor Yellow
Write-Host ""
Write-Host "This operation will:" -ForegroundColor White
Write-Host "  1. Provision parallel Linux user 'dmgm' on rath15nas (/home/dmgm)" -ForegroundColor White
Write-Host "  2. Duplicate SSH keys from 'dmm' so David's current key works immediately" -ForegroundColor White
Write-Host "  3. Grant 'dmgm@pam' full Administrator permissions in Proxmox VE" -ForegroundColor White
Write-Host "  4. Verify WireGuard firewall rules for incoming management and services" -ForegroundColor White
Write-Host "  5. Provision 'dmgm' inside LXC 920 (services) with sudo and docker rights" -ForegroundColor White
Write-Host "  6. Add 'dmgm' into Authelia SSO (admins group) and display initial password" -ForegroundColor White
Write-Host "  7. Verify Restic offsite backup vault health on 10.10.0.4:8000" -ForegroundColor White
Write-Host ""

$Confirm = Read-Host "Proceed with provisioning dmgm as Co-Administrator? (Y/n) [Y]"
if ($Confirm -match "^[nN]") {
    Write-Host "[-] Cancelled." -ForegroundColor Red
    exit 0
}

$RemoteTmp = "/tmp/16-setup-dmgm-coadmin.sh"
Write-Host "`n[*] Staging script to $RemoteHost:$RemoteTmp via scp..." -ForegroundColor Green
scp -i ~/.ssh/id_ed25519 "$ScriptPath" "$SshUser@$RemoteHost`:$RemoteTmp"
ssh -i ~/.ssh/id_ed25519 "$SshUser@$RemoteHost" "chmod +x $RemoteTmp"

Write-Host "[*] Executing script interactively on $RemoteHost via SSH..." -ForegroundColor Green
Write-Host "    (You will be prompted for your '$SshUser' sudo password)" -ForegroundColor Yellow
ssh -t -i ~/.ssh/id_ed25519 "$SshUser@$RemoteHost" "sudo bash $RemoteTmp"

Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "    Deployment script execution finished." -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

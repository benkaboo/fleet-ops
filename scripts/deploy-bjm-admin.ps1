# ==============================================================================
# Provision Administrative Operator (bjm) in LXC 920
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
    $ScriptPath = Join-Path $ScriptDir "lxc-setup\15-setup-bjm-admin.sh"
}

Clear-Host
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "    Provision Admin User 'bjm' in LXC 920 (services)" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

if (-not (Test-Path $ScriptPath)) {
    Write-Error "Script not found at: $ScriptPath"
    exit 1
}

Write-Host "[*] Target Host: $SshUser@$RemoteHost" -ForegroundColor Yellow
Write-Host "[*] Script:      $ScriptPath" -ForegroundColor Yellow
Write-Host ""

$Confirm = Read-Host "Proceed with provisioning bjm on LXC 920? (Y/n) [Y]"
if ($Confirm -match "^[nN]") {
    Write-Host "[-] Cancelled." -ForegroundColor Red
    exit 0
}

Write-Host "`n[*] Transferring and executing script on $RemoteHost via SSH..." -ForegroundColor Green
$ScriptContent = Get-Content -Raw -Path $ScriptPath -Encoding utf8

# Execute cleanly over SSH stdin without command-line escaping issues
$ScriptContent | ssh -t "$SshUser@$RemoteHost" "sudo bash"

Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "    Done! You can now connect directly via VS Code Remote-SSH to LXC 920." -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

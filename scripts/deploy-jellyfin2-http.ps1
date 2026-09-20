# ==============================================================================
# Enable Plain HTTP Relay for Remote Jellyfin on Proxmox Host (rath15nas)
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
    $ScriptPath = Join-Path $ScriptDir "lxc-setup\18-enable-jellyfin2-http.sh"
}

Clear-Host
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "    Enable Plain HTTP Relay for Remote Jellyfin on rath15nas (LXC 920)" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

if (-not (Test-Path $ScriptPath)) {
    Write-Error "Script not found at: $ScriptPath"
    exit 1
}

Write-Host "[*] Target Host: $SshUser@$RemoteHost (Proxmox VE)" -ForegroundColor Yellow
Write-Host "[*] Script:      $ScriptPath" -ForegroundColor Yellow
Write-Host ""
Write-Host "This operation will:" -ForegroundColor White
Write-Host "  1. Backup /opt/stacks/caddy/Caddyfile in LXC 920" -ForegroundColor White
Write-Host "  2. Append plain HTTP listener for http://jellyfin2.192.168.68.175.nip.io" -ForegroundColor White
Write-Host "  3. Validate Caddyfile syntax inside the container" -ForegroundColor White
Write-Host "  4. Reload Caddy configuration with zero service downtime" -ForegroundColor White
Write-Host ""

$RemoteTmp = "/tmp/18-enable-jellyfin2-http.sh"
Write-Host "[*] Staging script to $RemoteHost:$RemoteTmp via scp..." -ForegroundColor Green
scp -i ~/.ssh/id_ed25519 "$ScriptPath" "$SshUser@$RemoteHost`:$RemoteTmp"
ssh -i ~/.ssh/id_ed25519 "$SshUser@$RemoteHost" "chmod +x $RemoteTmp"

Write-Host "[*] Executing script interactively on $RemoteHost via SSH..." -ForegroundColor Green
Write-Host "    (You will be prompted for your '$SshUser' sudo password)" -ForegroundColor Yellow
ssh -t -i ~/.ssh/id_ed25519 "$SshUser@$RemoteHost" "sudo bash $RemoteTmp"

Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "    Done! You can now connect your Google TV app via:" -ForegroundColor Cyan
Write-Host "    http://jellyfin2.192.168.68.175.nip.io" -ForegroundColor Yellow
Write-Host "======================================================================" -ForegroundColor Cyan

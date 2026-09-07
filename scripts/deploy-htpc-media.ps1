# ==============================================================================
# Deploy Dedicated HTPC User & [Media] Share to Proxmox Host
# Run directly from PowerShell on your Windows workstation
# ==============================================================================

[CmdletBinding()]
param(
    [string]$HostIp = "192.168.68.169",
    [string]$SshUser = "bjm"
)

Clear-Host
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "    Deploy HTPC User & [Media] Samba Share to $HostIp" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Target Host: $SshUser@$HostIp`n"

$ScriptPath = Join-Path $PSScriptRoot "setup-htpc-media-share.sh"
if (-not (Test-Path $ScriptPath)) {
    Write-Error "Could not find $ScriptPath"
    exit 1
}

Write-Host "[*] Copying setup-htpc-media-share.sh to $SshUser@$HostIp:~/..." -ForegroundColor Gray
scp "$ScriptPath" "$($SshUser)@$($HostIp):~/setup-htpc-media-share.sh"

Write-Host "[*] Executing setup script interactively on remote host..." -ForegroundColor Yellow
Write-Host "    (You will be prompted for your sudo password and the new HTPC Samba password)`n"
ssh -t "$($SshUser)@$($HostIp)" "chmod +x ~/setup-htpc-media-share.sh && sudo ~/setup-htpc-media-share.sh && rm ~/setup-htpc-media-share.sh"

Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "    Deployment Finished!" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "On your HTPC, run the following in PowerShell / Command Prompt:" -ForegroundColor Yellow
Write-Host "1. Save credentials (replaces any anonymous sessions):"
Write-Host "   cmdkey /add:$HostIp /user:htpc /pass:<YourChosenPassword>" -ForegroundColor Green
Write-Host "   cmdkey /add:rath15nas /user:htpc /pass:<YourChosenPassword>" -ForegroundColor Green
Write-Host "2. Mount drive M: for DVD ripping:"
Write-Host "   net use M: \\$HostIp\Media /persistent:yes" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Cyan

<#
.SYNOPSIS
    Deploys and executes the Steam Streaming readiness check on rath15-htpc from your Workstation.
.DESCRIPTION
    1. Uploads ensure_steam_stream.ps1 to rath15-htpc via SCP.
    2. Runs the script remotely via SSH to configure Steam for 'coppertrumpet2' in Session 1.
    3. Performs an end-to-end connectivity test from Workstation to HTPC port 27036.
#>

[CmdletBinding()]
param(
    [string]$TargetHost = "rath15-htpc",
    [string]$TargetAccount = "coppertrumpet2"
)

$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
$localScript = Join-Path $scriptDir "ensure_steam_stream.ps1"
$remoteScriptPath = "C:\Users\benka_000\ensure_steam_stream.ps1"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Triggering Steam Streaming Setup on $TargetHost...       " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Upload script to HTPC
Write-Host "`n[1] Uploading check script to $TargetHost via SCP..." -ForegroundColor Yellow
scp -B -o BatchMode=yes $localScript "${TargetHost}:${remoteScriptPath}"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to SCP script to $TargetHost." -ForegroundColor Red
    exit 1
}
Write-Host "Upload complete." -ForegroundColor Green

# 2. Execute script via SSH
Write-Host "`n[2] Executing setup script remotely on $TargetHost..." -ForegroundColor Yellow
ssh -o BatchMode=yes $TargetHost "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$remoteScriptPath`" -TargetAccount `"$TargetAccount`""

# 3. Workstation-side Network Verification
Write-Host "`n[3] Verifying Remote Play connection from Workstation..." -ForegroundColor Yellow
$test = Test-NetConnection -ComputerName 192.168.68.162 -Port 27036 -WarningAction SilentlyContinue
if ($test.TcpTestSucceeded) {
    Write-Host "[SUCCESS] Port 27036 is actively listening on $TargetHost and reachable from Workstation!" -ForegroundColor Green
    Write-Host "`n>> Open Steam on your Workstation. Select any installed game on HTPC and click 'Stream'!" -ForegroundColor Cyan
} else {
    Write-Host "[WARN] Port 27036 did not respond immediately. Give Steam a few seconds to complete startup." -ForegroundColor Yellow
}

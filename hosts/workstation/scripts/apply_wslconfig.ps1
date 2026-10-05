<#
.SYNOPSIS
    Applies the resource-constrained .wslconfig to %USERPROFILE%\.wslconfig.
.DESCRIPTION
    1. Backs up existing .wslconfig if present.
    2. Copies configs/.wslconfig to %USERPROFILE%\.wslconfig.
    3. Runs wsl --shutdown to ensure limits take effect.
    4. Verifies configuration.
#>

[CmdletBinding()]
param()

$baseDir = Split-Path -Parent $PSScriptRoot
$sourceConfig = Join-Path $baseDir "configs\.wslconfig"
$targetConfig = Join-Path $env:USERPROFILE ".wslconfig"
$reportsDir = Join-Path $baseDir "reports"

if (-not (Test-Path $sourceConfig)) {
    Write-Error "Source configuration not found at: $sourceConfig"
    return
}

# 1. Backup if exists
if (Test-Path $targetConfig) {
    $backupFile = Join-Path $reportsDir "backup_wslconfig_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    Copy-Item -Path $targetConfig -Destination $backupFile -Force
    Write-Host "Backed up existing .wslconfig to: $backupFile" -ForegroundColor Green
} else {
    Write-Host "No prior .wslconfig detected in $env:USERPROFILE." -ForegroundColor Cyan
}

# 2. Apply config
Copy-Item -Path $sourceConfig -Destination $targetConfig -Force
Write-Host "Applied .wslconfig to: $targetConfig" -ForegroundColor Green

# 3. Gracefully shutdown WSL to load new config
Write-Host "Issuing wsl --shutdown to enforce new resource bounds..." -ForegroundColor Cyan
wsl.exe --shutdown

# 4. Verify
Write-Host "`n=== Verification: %USERPROFILE%\.wslconfig Content ===" -ForegroundColor Cyan
Get-Content -Path $targetConfig

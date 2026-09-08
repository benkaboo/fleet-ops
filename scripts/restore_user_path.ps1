<#
.SYNOPSIS
    Restores original User PATH from backup.
#>

[CmdletBinding()]
param()

$baseDir = Split-Path -Parent $PSScriptRoot
$backupFile = Join-Path $baseDir "reports\backup_user_path.txt"

if (-not (Test-Path $backupFile)) {
    Write-Error "Backup file not found at: $backupFile"
    return
}

$originalPath = Get-Content -Path $backupFile -Raw
Set-ItemProperty -Path "HKCU:\Environment" -Name "Path" -Value $originalPath -Force
Write-Host "Restored original User PATH to HKCU:\Environment!" -ForegroundColor Green

Write-Host "`n=== Verification: Restored User PATH ===" -ForegroundColor Cyan
$verified = (Get-ItemProperty -Path "HKCU:\Environment" -Name "Path").Path -split ";" | Where-Object { $_ }
foreach ($v in $verified) {
    Write-Host "  - $v"
}

<#
.SYNOPSIS
    Restores browser background pre-launchers from backup.
.DESCRIPTION
    Reads reports/backup_browser_autostart.json and re-registers the keys in HKCU Run.
#>

[CmdletBinding()]
param()

$baseDir = Split-Path -Parent $PSScriptRoot
$backupFile = Join-Path $baseDir "reports\backup_browser_autostart.json"
$hkcuRunPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

if (-not (Test-Path $backupFile)) {
    Write-Error "Backup file not found at: $backupFile"
    return
}

$rawJson = Get-Content $backupFile -Raw
$entries = $rawJson | ConvertFrom-Json

foreach ($prop in $entries.PSObject.Properties) {
    Set-ItemProperty -Path $hkcuRunPath -Name $prop.Name -Value $prop.Value -Force
    Write-Host "Restored to HKCU Run: $($prop.Name)" -ForegroundColor Green
}

Write-Host "`n=== Verification: Updated HKCU Run Entries ===" -ForegroundColor Cyan
Get-ItemProperty -Path $hkcuRunPath | Select-Object -Property * -ExcludeProperty PS* | Format-List

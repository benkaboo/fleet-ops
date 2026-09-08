<#
.SYNOPSIS
    Disables browser background pre-launchers (Chrome, Edge, Copilot) from autostarting.
.DESCRIPTION
    1. Backs up current values to reports/backup_browser_autostart.json.
    2. Removes GoogleChromeAutoLaunch*, MicrosoftEdgeAutoLaunch*, and MicrosoftCopilotAutoLaunch* from HKCU Run.
    3. Verifies remaining registry entries.
#>

[CmdletBinding()]
param()

$baseDir = Split-Path -Parent $PSScriptRoot
$reportsDir = Join-Path $baseDir "reports"
if (-not (Test-Path $reportsDir)) {
    New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
}

$backupFile = Join-Path $reportsDir "backup_browser_autostart.json"
$hkcuRunPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

$props = Get-ItemProperty -Path $hkcuRunPath
$browserEntries = @{}

foreach ($p in $props.PSObject.Properties) {
    if ($p.Name -match "^(GoogleChromeAutoLaunch|MicrosoftEdgeAutoLaunch|MicrosoftCopilotAutoLaunch)") {
        $browserEntries[$p.Name] = [string]$p.Value
    }
}

if ($browserEntries.Count -gt 0) {
    $browserEntries | ConvertTo-Json | Set-Content -Path $backupFile -Force
    Write-Host "Backed up $($browserEntries.Count) browser autostart entries to $backupFile" -ForegroundColor Green
    
    foreach ($entryName in $browserEntries.Keys) {
        Remove-ItemProperty -Path $hkcuRunPath -Name $entryName -Force
        Write-Host "Removed from autostart: $entryName" -ForegroundColor Green
    }
} else {
    Write-Host "No browser autostart entries found to remove." -ForegroundColor Yellow
}

Write-Host "`n=== Verification: Remaining HKCU Run Entries ===" -ForegroundColor Cyan
Get-ItemProperty -Path $hkcuRunPath | Select-Object -Property * -ExcludeProperty PS* | Format-List

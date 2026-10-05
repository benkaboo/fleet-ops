<#
.SYNOPSIS
    Optimizes startup items by pruning non-essential game launchers and redundant helpers.
.DESCRIPTION
    1. Exports registry backups to reports/backup_run_hkcu.reg and reports/backup_run_hklm.reg.
    2. Removes EADM and GogGalaxy from HKCU Run.
    3. Removes Logitech Download Assistant from HKLM Run if elevated, or notes requirement.
    4. Verifies remaining entries.
#>

[CmdletBinding()]
param()

$baseDir = Split-Path -Parent $PSScriptRoot
$reportsDir = Join-Path $baseDir "reports"
if (-not (Test-Path $reportsDir)) {
    New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
}

$hkcuBackup = Join-Path $reportsDir "backup_run_hkcu.reg"
$hklmBackup = Join-Path $reportsDir "backup_run_hklm.reg"

Write-Host "Creating registry backups..." -ForegroundColor Cyan
& reg.exe export "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" $hkcuBackup /y | Out-Null
& reg.exe export "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" $hklmBackup /y | Out-Null

if (Test-Path $hkcuBackup) {
    Write-Host "Backed up HKCU Run key to $hkcuBackup" -ForegroundColor Green
}
if (Test-Path $hklmBackup) {
    Write-Host "Backed up HKLM Run key to $hklmBackup" -ForegroundColor Green
}

# 1. Prune HKCU entries
$hkcuRunPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$targetsHKCU = @("EADM", "GogGalaxy")

foreach ($target in $targetsHKCU) {
    $prop = Get-ItemProperty -Path $hkcuRunPath -Name $target -ErrorAction SilentlyContinue
    if ($prop) {
        Remove-ItemProperty -Path $hkcuRunPath -Name $target -Force -ErrorAction Stop
        Write-Host "Successfully removed from HKCU Run: $target" -ForegroundColor Green
    } else {
        Write-Host "Target not found in HKCU Run (already absent): $target" -ForegroundColor Yellow
    }
}

# 2. Check HKLM entry
$hklmRunPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
$targetHKLM = "Logitech Download Assistant"
$propHKLM = Get-ItemProperty -Path $hklmRunPath -Name $targetHKLM -ErrorAction SilentlyContinue

if ($propHKLM) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        Remove-ItemProperty -Path $hklmRunPath -Name $targetHKLM -Force -ErrorAction Stop
        Write-Host "Successfully removed from HKLM Run: $targetHKLM" -ForegroundColor Green
    } else {
        Write-Host "HKLM modification requires Administrator elevation. Target '$targetHKLM' in HKLM Run preserved or requires elevated terminal." -ForegroundColor Yellow
    }
} else {
    Write-Host "Target not found in HKLM Run (already absent): $targetHKLM" -ForegroundColor Yellow
}

Write-Host "`n=== Verification: Remaining HKCU Run Entries ===" -ForegroundColor Cyan
Get-ItemProperty -Path $hkcuRunPath | Select-Object -Property * -ExcludeProperty PS* | Format-List

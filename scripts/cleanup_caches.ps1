<#
.SYNOPSIS
    Tier 2 Ephemeral Cache Cleanup script.
.DESCRIPTION
    Safely purges npm cache, pip cache, and stale User %TEMP% files.
#>

[CmdletBinding()]
param()

$totalReclaimedBytes = 0

# 1. npm cache clean
Write-Host "Purging npm cache..." -ForegroundColor Cyan
$npmCachePath = "$env:LOCALAPPDATA\npm-cache"
if (Test-Path $npmCachePath) {
    $beforeSize = (Get-ChildItem -Path $npmCachePath -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    cmd.exe /c "npm cache clean --force" 2>&1 | Out-Null
    $afterSize = if (Test-Path $npmCachePath) { (Get-ChildItem -Path $npmCachePath -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum } else { 0 }
    $reclaimed = [math]::Max(0, ($beforeSize - $afterSize))
    $totalReclaimedBytes += $reclaimed
    Write-Host "  npm cache cleaned! Reclaimed: $([math]::Round($reclaimed / 1MB, 2)) MB" -ForegroundColor Green
} else {
    Write-Host "  npm cache not present." -ForegroundColor Cyan
}

# 2. pip cache purge
Write-Host "`nPurging pip cache..." -ForegroundColor Cyan
$pipCachePath = "$env:LOCALAPPDATA\pip\cache"
if (Test-Path $pipCachePath) {
    $beforeSize = (Get-ChildItem -Path $pipCachePath -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    python -m pip cache purge 2>&1 | Out-Null
    $afterSize = if (Test-Path $pipCachePath) { (Get-ChildItem -Path $pipCachePath -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum } else { 0 }
    $reclaimed = [math]::Max(0, ($beforeSize - $afterSize))
    $totalReclaimedBytes += $reclaimed
    Write-Host "  pip cache cleaned! Reclaimed: $([math]::Round($reclaimed / 1MB, 2)) MB" -ForegroundColor Green
} else {
    Write-Host "  pip cache not present." -ForegroundColor Cyan
}

# 3. User %TEMP% clean (unlocked files only)
Write-Host "`nPurging stale User %TEMP% files..." -ForegroundColor Cyan
$tempFiles = Get-ChildItem -Path $env:TEMP -File -Force -ErrorAction SilentlyContinue
$tempDirs = Get-ChildItem -Path $env:TEMP -Directory -Force -ErrorAction SilentlyContinue
$tempReclaimed = 0

foreach ($f in $tempFiles) {
    try {
        $len = $f.Length
        Remove-Item -Path $f.FullName -Force -ErrorAction Stop
        $tempReclaimed += $len
    } catch {
        # File is in use by a running process, skip safely
    }
}

foreach ($d in $tempDirs) {
    try {
        Remove-Item -Path $d.FullName -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        # Directory in use, skip
    }
}

$totalReclaimedBytes += $tempReclaimed
Write-Host "  User %TEMP% cleaned! Reclaimed: $([math]::Round($tempReclaimed / 1MB, 2)) MB" -ForegroundColor Green

$totalMB = [math]::Round($totalReclaimedBytes / 1MB, 2)
Write-Host "`n=== Cache Cleanup Summary ===" -ForegroundColor Cyan
Write-Host "Total Ephemeral Space Reclaimed: $totalMB MB" -ForegroundColor Green

<#
.SYNOPSIS
    Cleans residual Python 3.12 site-packages and installs python3 command shim.
.DESCRIPTION
    1. Removes leftover C:\Users\benma\AppData\Local\Programs\Python\Python312 directory.
    2. Installs python3.cmd shim pointing to C:\Python314\python.exe in %LOCALAPPDATA%\agy\bin.
    3. Verifies toolchain resolution.
#>

[CmdletBinding()]
param()

$residualDir = "$env:LOCALAPPDATA\Programs\Python\Python312"

if (Test-Path $residualDir) {
    $sizeMB = [math]::Round(((Get-ChildItem -Path $residualDir -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB), 2)
    Write-Host "Cleaning residual Python 3.12 files ($sizeMB MB)..." -ForegroundColor Cyan
    Remove-Item -Path $residualDir -Recurse -Force -ErrorAction Stop
    Write-Host "Removed residual directory: $residualDir (Reclaimed $sizeMB MB)" -ForegroundColor Green
} else {
    Write-Host "Residual directory already clean." -ForegroundColor Cyan
}

# 2. Install python3.cmd shim
$shimDir = "$env:LOCALAPPDATA\agy\bin"
if (-not (Test-Path $shimDir)) {
    New-Item -ItemType Directory -Path $shimDir -Force | Out-Null
}

$shimFile = Join-Path $shimDir "python3.cmd"
$shimContent = '@"C:\Python314\python.exe" %*'
Set-Content -Path $shimFile -Value $shimContent -Force
Write-Host "Installed python3 shim to: $shimFile" -ForegroundColor Green

# 3. Verification
Write-Host "`n=== Verification: Python Environment Resolution ===" -ForegroundColor Cyan
Write-Host "1. py --list:"
py --list

Write-Host "`n2. python command:"
Get-Command python | Select-Object Name, Source
python --version

Write-Host "`n3. python3 command:"
Get-Command python3 | Select-Object Name, Source
& $shimFile --version

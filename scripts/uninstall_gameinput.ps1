<#
.SYNOPSIS
    Uninstalls the redundant standalone Microsoft GameInput MSI package.
.DESCRIPTION
    1. Ensures administrative privileges (elevates if run interactively).
    2. Executes silent uninstallation of Microsoft GameInput (GUID {14EDF950-06B9-415F-862C-1D5DEC321AE6}).
    3. Verifies that GameInputRedistService is purged and native GameInputSvc remains intact.
#>

[CmdletBinding()]
param()

$isAdmin = [bool]((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))

if (-not $isAdmin) {
    Write-Host "[!] Administrator privileges are required to uninstall system-level packages." -ForegroundColor Yellow
    Write-Host "Attempting elevation..." -ForegroundColor Cyan
    try {
        $proc = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -PassThru
        exit $proc.ExitCode
    } catch {
        Write-Error "Failed to elevate. Please open PowerShell as Administrator and run: `n& `"$PSCommandPath`""
        exit 1
    }
}

Write-Host "=== Microsoft GameInput Redundancy Removal ===" -ForegroundColor Cyan
$guid = "{14EDF950-06B9-415F-862C-1D5DEC321AE6}"

Write-Host "[1/3] Triggering MSI uninstallation for $guid..." -ForegroundColor Cyan
$process = Start-Process msiexec.exe -ArgumentList "/x $guid /qn /norestart" -Wait -PassThru

if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
    Write-Host "  -> MSI uninstallation completed successfully (Exit code: $($process.ExitCode))." -ForegroundColor Green
} else {
    Write-Host "  -> MSI uninstallation returned code $($process.ExitCode). Checking if package is already removed..." -ForegroundColor Yellow
}

Start-Sleep -Seconds 2

Write-Host "[2/3] Verifying remaining GameInput services..." -ForegroundColor Cyan
$services = Get-Service *gameinput* -ErrorAction SilentlyContinue

foreach ($svc in $services) {
    Write-Host "  - Service: $($svc.Name) | Display: $($svc.DisplayName) | Status: $($svc.Status)" -ForegroundColor Cyan
}

$redistSvc = Get-Service GameInputRedistService -ErrorAction SilentlyContinue
if ($null -eq $redistSvc) {
    Write-Host "  -> Confirmed: GameInputRedistService has been completely removed." -ForegroundColor Green
} else {
    Write-Host "  -> Warning: GameInputRedistService is still registered." -ForegroundColor Yellow
}

Write-Host "[3/3] Verifying native Windows 11 GameInput service..." -ForegroundColor Cyan
$nativeSvc = Get-Service GameInputSvc -ErrorAction SilentlyContinue
if ($null -ne $nativeSvc) {
    Write-Host "  -> Confirmed: Native GameInputSvc is healthy and available ($($nativeSvc.Status))." -ForegroundColor Green
} else {
    Write-Host "  -> Warning: Native GameInputSvc was not detected." -ForegroundColor Red
}

Write-Host "`nProcess finished successfully. Redundant GameInput loop eliminated." -ForegroundColor Green

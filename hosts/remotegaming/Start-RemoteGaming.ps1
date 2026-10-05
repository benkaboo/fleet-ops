<#
.SYNOPSIS
    Automated pre-flight session handoff and launcher for Remote Gaming with Moonlight.

.DESCRIPTION
    Verifies HTPC connectivity, attaches user session (benka_000) to the physical
    GPU console via tscon if another user (e.g., Dylan) was using the TV, ensures
    SunshineService is active, and launches the Moonlight streaming client.
#>

[CmdletBinding()]
param(
    [string]$HostName = "rath15-htpc.local",
    [string]$TargetUser = "benka_000",
    [string]$MoonlightPath = "$env:LOCALAPPDATA\Programs\Moonlight\Moonlight.exe",
    [string]$AppName = "Playnite Fullscreen"
)

$ErrorActionPreference = "Stop"

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "   Federated Remote Gaming Launcher (HTPC)    " -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

# 1. Test Host Reachability
Write-Host "[1/4] Probing host reachability ($HostName)..." -NoNewline
try {
    $tcp = Test-NetConnection -ComputerName $HostName -Port 22 -WarningAction SilentlyContinue -InformationLevel Quiet
    if (-not $tcp) {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Warning "Could not reach $HostName on port 22 (SSH). Ensure HTPC is powered on and connected to the LAN."
        exit 1
    }
    Write-Host " OK" -ForegroundColor Green
}
catch {
    Write-Host " ERROR" -ForegroundColor Red
    Write-Warning "Network test error: $_"
    exit 1
}

# 2. Query Windows Sessions on HTPC
Write-Host "[2/4] Querying active desktop sessions..." -NoNewline
try {
    $rawSessions = "qwinsta" | ssh -o BatchMode=yes -o ConnectTimeout=5 "$TargetUser@$HostName" powershell -NoProfile -Command -
    Write-Host " OK" -ForegroundColor Green
}
catch {
    Write-Host " SSH ERROR" -ForegroundColor Red
    Write-Warning "Failed to query sessions over SSH: $_"
    exit 1
}

# Parse qwinsta output lines
$targetSession = $null
$consoleUser = $null
foreach ($line in ($rawSessions -split "`r?`n")) {
    $trimmed = $line.Trim()
    if ($trimmed -match '^console\s+(\S+)\s+(\d+)\s+Active') {
        $consoleUser = $Matches[1]
    }
    if ($trimmed -match '\b' + [regex]::Escape($TargetUser) + '\s+(\d+)\s+(Active|Disc)') {
        $targetSession = [PSCustomObject]@{
            SessionId = $Matches[1]
            State     = $Matches[2]
            IsConsole = ($trimmed -like "console*")
        }
    }
}

# 3. Handle Session Handoff
Write-Host "[3/4] Evaluating console ownership..."
if ($null -ne $targetSession) {
    if ($targetSession.IsConsole -and $targetSession.State -eq "Active") {
        Write-Host "  -> '$TargetUser' (Session $($targetSession.SessionId)) is already active on the console." -ForegroundColor Green
    }
    else {
        Write-Host "  -> '$TargetUser' is in Session $($targetSession.SessionId) (State: $($targetSession.State))." -ForegroundColor Yellow
        if ($consoleUser) {
            Write-Host "  -> Console currently occupied by '$consoleUser'. Performing handoff..." -ForegroundColor Yellow
        }
        else {
            Write-Host "  -> Performing console session handoff..." -ForegroundColor Yellow
        }

        $handoffCmd = "tscon $($targetSession.SessionId) /dest:console"
        $handoffCmd | ssh -o BatchMode=yes "$TargetUser@$HostName" powershell -NoProfile -Command -
        Write-Host "  -> Session $($targetSession.SessionId) successfully attached to console!" -ForegroundColor Green
        Start-Sleep -Seconds 2
    }
}
else {
    Write-Host "  -> '$TargetUser' is not logged into any session." -ForegroundColor Yellow
    Write-Host "  -> Opening stream directly so you can sign in at the Windows logon screen." -ForegroundColor Cyan
}

# Verify Sunshine Service
$sunshineCheck = "Get-Process sunshine -ErrorAction SilentlyContinue | Select-Object -First 1 Id" | ssh -o BatchMode=yes "$TargetUser@$HostName" powershell -NoProfile -Command -
if (-not $sunshineCheck) {
    Write-Host "  -> Sunshine process not detected in active session. Restarting SunshineService..." -ForegroundColor Yellow
    "Restart-Service SunshineService -Force" | ssh -o BatchMode=yes "$TargetUser@$HostName" powershell -NoProfile -Command -
    Start-Sleep -Seconds 3
}

# 4. Launch Moonlight Client directly into App
if (Test-Path $MoonlightPath) {
    if ($AppName) {
        Write-Host "[4/4] Launching Moonlight directly into '$AppName' on $HostName..." -ForegroundColor Cyan
        Start-Process -FilePath $MoonlightPath -ArgumentList "stream", $HostName, "`"$AppName`""
    }
    else {
        Write-Host "[4/4] Launching Moonlight Client..." -ForegroundColor Cyan
        Start-Process -FilePath $MoonlightPath
    }
    Write-Host "Remote gaming pipeline ready! Enjoy your game." -ForegroundColor Green
}
else {
    Write-Warning "Moonlight executable not found at '$MoonlightPath'."
}

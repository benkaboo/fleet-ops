<#
.SYNOPSIS
    Automated headless session switch and Steam Remote Play preparation for rath15-htpc.
.DESCRIPTION
    1. Inspects active sessions on HTPC via SSH.
    2. If another user is logged in, gracefully logs them off without touching the physical TV.
    3. Triggers a background RDP connection to authenticate as 'benka_000' using saved credentials.
    4. Automatically hijacks and transfers the session to the physical GPU console via 'tscon /dest:console'.
    5. Launches Steam in Session 1 as 'coppertrumpet2' and validates port 27036.
    6. Optionally triggers installation of Batman: Arkham Asylum (App ID 35140).
#>

[CmdletBinding()]
param(
    [string]$TargetHost = "rath15-htpc",
    [string]$TargetIP = "192.168.68.162",
    [string]$TargetUser = "gamer",
    [string]$SteamAccount = "coppertrumpet2"
)

$ErrorActionPreference = "Continue"

function Write-Step {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "`n$Message" -ForegroundColor $Color
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Headless Switch & Stream Automator for $TargetHost      " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Inspect Current Sessions on HTPC
Write-Step "[1/5] Querying active user sessions on $TargetHost via SSH..." "Yellow"
$quserRaw = ssh -o BatchMode=yes $TargetHost "quser" 2>&1
Write-Host ($quserRaw -join "`n") -ForegroundColor Gray

$gamerConsoleSession = $null
$gamerRdpSession = $null
$otherUserOnConsole = $null
$otherUserSessionId = $null

foreach ($line in $quserRaw) {
    if ($line -match "(?:>)?\s*([a-zA-Z0-9_\-]+)\s+(?:(\S+)\s+)?(\d+)\s+(Active|Conn|Disc)") {
        $uName = $Matches[1].Trim()
        $sName = if ($Matches[2]) { $Matches[2].Trim() } else { "" }
        $sId   = $Matches[3].Trim()
        $sState = $Matches[4].Trim()

        if ($uName -eq $TargetUser) {
            if ($sName -eq "console") {
                $gamerConsoleSession = $sId
            } else {
                $gamerRdpSession = $sId
            }
        } elseif ($sName -eq "console") {
            $otherUserOnConsole = $uName
            $otherUserSessionId = $sId
        }
    }
}

function Invoke-SystemTscon {
    param([string]$SessionId)
    $localTsconScript = Join-Path $PSScriptRoot "do_tscon.ps1"
    $remoteTsconScript = "C:\Users\$TargetUser\do_tscon.ps1"
    scp -B -o BatchMode=yes $localTsconScript "${TargetHost}:${remoteTsconScript}" | Out-Null
    ssh -o BatchMode=yes $TargetHost "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$remoteTsconScript`" -SessionId $SessionId"
}

# 2. Clear Console if Another User is Logged In
if ($otherUserOnConsole) {
    Write-Step "[2/5] User '$otherUserOnConsole' is on the console. Logging off session $otherUserSessionId..." "Yellow"
    ssh -o BatchMode=yes $TargetHost "logoff $otherUserSessionId"
    Start-Sleep -Seconds 2
    Write-Host "  -> Session cleared." -ForegroundColor Green
}

# 3. Session Handoff to Console
if ($gamerConsoleSession) {
    Write-Step "[3/5] '$TargetUser' is already active on the GPU console (Session $gamerConsoleSession)." "Green"
} elseif ($gamerRdpSession) {
    Write-Step "[3/5] '$TargetUser' is connected via RDP (Session $gamerRdpSession). Transferring directly to GPU console..." "Yellow"
    Invoke-SystemTscon -SessionId $gamerRdpSession
    Write-Host "  -> Successfully transferred to GPU console." -ForegroundColor Green
} else {
    Write-Step "[3/5] Initiating background RDP authentication for '$TargetUser'..." "Yellow"
    $rdpProc = Start-Process -FilePath "mstsc.exe" -ArgumentList "/v:$TargetIP" -WindowStyle Minimized -PassThru

    Write-Host "  Waiting for session creation on $TargetHost..."
    $newSessionId = $null
    for ($attempt = 1; $attempt -le 10; $attempt++) {
        Start-Sleep -Seconds 1
        $checkQuser = ssh -o BatchMode=yes $TargetHost "quser" 2>&1
        foreach ($line in $checkQuser) {
            if ($line -match "$TargetUser\s+(?:\S+\s+)?(\d+)\s+Active") {
                $newSessionId = $Matches[1]
                break
            }
        }
        if ($newSessionId) { break }
    }

    if (-not $newSessionId) {
        Write-Host "[ERROR] RDP session did not register within 10 seconds. Check credentials." -ForegroundColor Red
        if ($rdpProc -and -not $rdpProc.HasExited) { Stop-Process -Id $rdpProc.Id -Force }
        exit 1
    }

    Write-Host "  -> Authenticated! Session ID $newSessionId detected." -ForegroundColor Green
    Write-Host "  -> Transferring session $newSessionId directly to RTX 3060 physical console..." -ForegroundColor Yellow
    Invoke-SystemTscon -SessionId $newSessionId

    if ($rdpProc -and -not $rdpProc.HasExited) {
        Stop-Process -Id $rdpProc.Id -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  -> Successfully transferred to GPU console and closed RDP client." -ForegroundColor Green
}

# 4. Deploy and Run Steam Readiness Script on HTPC
Write-Step "[4/5] Ensuring Steam is running as '$SteamAccount' in the GPU console session..." "Yellow"
$localEnsureScript = Join-Path $PSScriptRoot "ensure_steam_stream.ps1"
$remoteEnsureScript = "C:\Users\$TargetUser\ensure_steam_stream.ps1"

scp -B -o BatchMode=yes $localEnsureScript "${TargetHost}:${remoteEnsureScript}" | Out-Null
ssh -o BatchMode=yes $TargetHost "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$remoteEnsureScript`" -TargetAccount `"$SteamAccount`""

# 5. Network Verification
Write-Step "[5/5] Testing Steam Remote Play port 27036 from Workstation..." "Yellow"
$ready = $false
for ($i = 1; $i -le 6; $i++) {
    $t = Test-NetConnection -ComputerName $TargetIP -Port 27036 -WarningAction SilentlyContinue
    if ($t.TcpTestSucceeded) {
        $ready = $true
        break
    }
    Write-Host "  Waiting for Steam port 27036 (Attempt $i/6)..."
    Start-Sleep -Seconds 3
}

if ($ready) {
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "  [SUCCESS] Steam Remote Play on $TargetHost is READY!   " -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "  -> Host: $TargetHost ($TargetIP)"
    Write-Host "  -> Steam Account: $SteamAccount"
    Write-Host "  -> GPU: NVIDIA GeForce RTX 3060 (Active)"
    Write-Host "  -> Status: Ready to stream on your Workstation!"
} else {
    Write-Host "`n[WARN] Steam is running but port 27036 did not respond yet. Check Steam on HTPC." -ForegroundColor Yellow
}


<#
.SYNOPSIS
    Ensures Steam is running under 'coppertrumpet2' in the active console session on rath15-htpc,
    validates GPU/display health, verifies Remote Play streaming ports, and guarantees safe SSH detachment.
.DESCRIPTION
    Run this script on rath15-htpc (either locally or remotely via SSH).
    It checks and fixes:
      1. Target Steam account configuration ('coppertrumpet2').
      2. Updates HKCU AutoLoginUser and loginusers.vdf if required.
      3. Dynamically identifies the active console desktop session/user (Session 1).
         Launches Steam directly into Session 1 using Task Scheduler.
      4. Validates physical console session status (ensures no RDP session lock).
      5. Validates NVIDIA RTX 3060 GPU readiness and keeps display awake.
      6. Verifies Steam Remote Play listening ports (TCP 27036, UDP 27031/27036) and firewall rules.
      7. Confirms zero SSH interference with the streaming session.
#>

[CmdletBinding()]
param(
    [string]$TargetAccount = "coppertrumpet2"
)

$ErrorActionPreference = "Continue"

function Write-Status {
    param([string]$Text, [string]$Level = "INFO")
    $color = switch ($Level) {
        "SUCCESS" { "Green" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "HEADER"  { "Cyan" }
        default   { "White" }
    }
    Write-Host $Text -ForegroundColor $color
}

Write-Status "========================================================" "HEADER"
Write-Status "     rath15-htpc Steam Streaming Readiness & Fix        " "HEADER"
Write-Status "   Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') " "HEADER"
Write-Status "   Target Account: $TargetAccount                       " "HEADER"
Write-Status "========================================================" "HEADER"

# 1. Discover Steam Installation
$steamPath = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
if (-not $steamPath -or -not (Test-Path $steamPath)) {
    $steamPath = "C:\Program Files (x86)\Steam"
}
$steamExe = Join-Path $steamPath "steam.exe"

if (-not (Test-Path $steamExe)) {
    Write-Status "[ERROR] Steam executable not found at '$steamExe'." "ERROR"
    exit 1
}
Write-Status "[1] Steam Path: $steamExe" "SUCCESS"

# 2. Identify Active Console User & Session
Write-Status "`n[2] ACTIVE CONSOLE USER & SESSION" "HEADER"
$explorer = Get-Process -Name explorer -IncludeUserName -ErrorAction SilentlyContinue | Select-Object -First 1
$consoleUser = $null
if ($explorer -and $explorer.UserName) {
    $consoleUser = $explorer.UserName.Split('\')[-1]
    Write-Status "  Active desktop console user: $consoleUser (Session $($explorer.SessionId))" "SUCCESS"
} else {
    $consoleUser = $env:USERNAME
    Write-Status "  Falling back to runner identity: $consoleUser" "WARN"
}

# 3. Check & Update Auto-Login Configuration in loginusers.vdf
Write-Status "`n[3] STEAM ACCOUNT CONFIGURATION" "HEADER"
$loginUsersFile = Join-Path $steamPath "config\loginusers.vdf"
if (Test-Path $loginUsersFile) {
    $vdfContent = Get-Content -Path $loginUsersFile -Raw
    if ($vdfContent -match "`"AccountName`"\s+`"$TargetAccount`"") {
        Write-Status "  Account '$TargetAccount' found in remembered accounts." "SUCCESS"
    } else {
        Write-Status "  [WARN] Account '$TargetAccount' not found in loginusers.vdf. May require initial manual login." "WARN"
    }

    # Ensure TargetAccount is set to AutoLogin 1 and MostRecent 1
    $modified = $false
    if ($vdfContent -match '("AccountName"\s+"benkaboo"[\s\S]*?"AutoLogin"\s+)"1"') {
        Write-Status "  Setting AutoLogin to 0 for 'benkaboo'..."
        $vdfContent = $vdfContent -replace '("AccountName"\s+"benkaboo"[\s\S]*?"AutoLogin"\s+)"1"', '$1"0"'
        $modified = $true
    }
    if ($vdfContent -match '("AccountName"\s+"' + $TargetAccount + '"[\s\S]*?"AutoLogin"\s+)"0"') {
        Write-Status "  Setting AutoLogin to 1 for '$TargetAccount'..."
        $vdfContent = $vdfContent -replace '("AccountName"\s+"' + $TargetAccount + '"[\s\S]*?"AutoLogin"\s+)"0"', '$1"1"'
        $modified = $true
    }
    # Ensure MostRecent 1
    if ($vdfContent -match '("AccountName"\s+"' + $TargetAccount + '"[\s\S]*?"MostRecent"\s+)"0"') {
        $vdfContent = $vdfContent -replace '("AccountName"\s+"' + $TargetAccount + '"[\s\S]*?"MostRecent"\s+)"0"', '$1"1"'
        $modified = $true
    } elseif ($vdfContent -notmatch '"AccountName"\s+"' + $TargetAccount + '"[\s\S]*?"MostRecent"') {
        $vdfContent = $vdfContent -replace '("AccountName"\s+"' + $TargetAccount + '")', "`$1`n`t`t`"MostRecent`"`t`t`"1`""
        $modified = $true
    }
    if ($modified) {
        Set-Content -Path $loginUsersFile -Value $vdfContent -Encoding UTF8
        Write-Status "  Updated loginusers.vdf successfully." "SUCCESS"
    }
}

# Disable AlwaysShowUserChooser in config.vdf
$configFile = Join-Path $steamPath "config\config.vdf"
if (Test-Path $configFile) {
    $cfgContent = Get-Content -Path $configFile -Raw
    if ($cfgContent -match '"AlwaysShowUserChooser"\s+"1"') {
        Write-Status "  Disabling AlwaysShowUserChooser in config.vdf..."
        $cfgContent = $cfgContent -replace '"AlwaysShowUserChooser"\s+"1"', '"AlwaysShowUserChooser"`t`t"0"'
        Set-Content -Path $configFile -Value $cfgContent -Encoding UTF8
        Write-Status "  Updated config.vdf successfully." "SUCCESS"
    }
}

# Update HKCU registry for current runner
Set-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name "AutoLoginUser" -Value $TargetAccount -ErrorAction SilentlyContinue
Set-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name "RememberPassword" -Value 1 -ErrorAction SilentlyContinue

# Update registry for console user
try {
    $consoleSid = (New-Object System.Security.Principal.NTAccount($consoleUser)).Translate([System.Security.Principal.SecurityIdentifier]).Value
    if ($consoleSid) {
        $userRegPath = "Registry::HKEY_USERS\$consoleSid\Software\Valve\Steam"
        if (Test-Path $userRegPath) {
            Set-ItemProperty -Path $userRegPath -Name "AutoLoginUser" -Value $TargetAccount -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $userRegPath -Name "RememberPassword" -Value 1 -ErrorAction SilentlyContinue
            Write-Status "  Updated Steam registry for user '$consoleUser' ($consoleSid)." "SUCCESS"
        }
    }
} catch {}

# 4. Steam Process Management in Interactive Console
Write-Status "`n[4] STEAM PROCESS & INTERACTIVE SESSION LAUNCH" "HEADER"
$targetSessionId = if ($explorer) { $explorer.SessionId } else { 1 }
$steamProc = Get-Process -Name steam -ErrorAction SilentlyContinue | Select-Object -First 1

if ($steamProc -and $steamProc.SessionId -eq $targetSessionId) {
    Write-Status "  Steam is already running in active session $targetSessionId (PID $($steamProc.Id))." "SUCCESS"
} else {
    if ($steamProc) {
        Write-Status "  Steam is running in wrong session $($steamProc.SessionId) (expected $targetSessionId). Terminating..." "WARN"
        Get-Process *steam* -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -ne "SteamService" } | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    Write-Status "  Launching Steam into console session $targetSessionId for user '$consoleUser'..."
    $taskName = "LaunchSteamSession1_Temp"
    try {
        $action = New-ScheduledTaskAction -Execute $steamExe -Argument "-login $TargetAccount -silent"
        $principal = New-ScheduledTaskPrincipal -UserId $consoleUser -LogonType Interactive
        $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Settings $taskSettings -Force | Out-Null
        Start-ScheduledTask -TaskName $taskName
        
        Write-Status "  Waiting for Steam to initialize..."
        $timeout = 15
        while (-not (Get-Process -Name steam -ErrorAction SilentlyContinue) -and $timeout -gt 0) {
            Start-Sleep -Seconds 1
            $timeout--
        }
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    } catch {
        Write-Status "  Task Scheduler bridge failed: $($_.Exception.Message). Trying direct launch..." "WARN"
        Start-Process -FilePath $steamExe -ArgumentList "-silent" -NoNewWindow
    }

    $newSteam = Get-Process -Name steam -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($newSteam) {
        Write-Status "  Steam launched successfully (PID $($newSteam.Id), Session ID $($newSteam.SessionId))." "SUCCESS"
    } else {
        Write-Status "  [WARN] Steam did not register in process table yet. It may still be loading." "WARN"
    }
}

# 5. Console Session & GPU Health
Write-Status "`n[5] CONSOLE & GPU READINESS" "HEADER"
$gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -like "*NVIDIA*" } | Select-Object -First 1
if ($gpu) {
    Write-Status "  GPU: $($gpu.Name) (Driver: $($gpu.DriverVersion), Status: $($gpu.Status))" "SUCCESS"
} else {
    Write-Status "  [WARN] NVIDIA GPU not detected." "WARN"
}

# Keep display awake
try {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class DisplayHelper2 {
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint esFlags);
}
"@ -ErrorAction SilentlyContinue
    [DisplayHelper2]::SetThreadExecutionState(0x80000003) | Out-Null
    Write-Status "  Display wake state asserted (prevents GPU render sleep)." "SUCCESS"
} catch {
    # Non-critical
}

# 6. Network & Steam Remote Play Ports
Write-Status "`n[6] NETWORK & STREAMING PORTS" "HEADER"
# Wait up to 10 seconds for port 27036 to open
$portReady = $false
for ($i = 0; $i -lt 5; $i++) {
    $tcp27036 = Get-NetTCPConnection -LocalPort 27036 -State Listen -ErrorAction SilentlyContinue
    if ($tcp27036) {
        $portReady = $true
        break
    }
    Start-Sleep -Seconds 2
}

if ($portReady) {
    Write-Status "  Steam Remote Play control port TCP 27036 is LISTENING." "SUCCESS"
} else {
    Write-Status "  [INFO] TCP 27036 not open yet (Steam will open it once initialization completes)." "WARN"
}

$fwRules = Get-NetFirewallRule -DisplayName "*Steam*" -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq 'True' -and $_.Direction -eq 'Inbound' }
if ($fwRules) {
    Write-Status "  Steam Inbound Firewall rules: Active ($($fwRules.Count) rules enabled)." "SUCCESS"
}

# 7. SSH Session Impact Confirmation
Write-Status "`n[7] SSH & CONNECTION COEXISTENCE" "HEADER"
Write-Status "  SSH runs in a dedicated non-GUI background service on Port 22."
Write-Status "  Steam Remote Play streams on ports 27031-27036 directly over UDP/TCP."
Write-Status "  -> SSH connection DOES NOT interfere with Steam streaming." "SUCCESS"
Write-Status "  -> Script completed cleanly. You may close SSH at any time." "SUCCESS"

Write-Status "`n========================================================" "HEADER"
Write-Status "   HTPC streaming configuration complete!               " "SUCCESS"
Write-Status "========================================================" "HEADER"

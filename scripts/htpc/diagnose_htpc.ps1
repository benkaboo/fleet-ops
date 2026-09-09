<#
.SYNOPSIS
    Diagnoses Remote Desktop (RDP), OpenSSH, User Accounts, and Network Firewall on rath15-htpc.
.DESCRIPTION
    Run this script locally on rath15-htpc in PowerShell.
    It checks:
      1. Windows OS edition (Home vs Pro).
      2. Remote Desktop (RDP) service and registry settings.
      3. Windows Hello Passwordless lockdown policy.
      4. Local user accounts and group memberships (Administrators, Remote Desktop Users).
      5. OpenSSH Server status.
      6. Network profile (Private vs Public) and Firewall rules.
    Outputs the findings to console and saves a report to htpc_diagnostics_report.txt.
#>

[CmdletBinding()]
param()

$reportPath = Join-Path $PSScriptRoot "htpc_diagnostics_report.txt"
$report = [System.Collections.Generic.List[string]]::new()

function Log-Output {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
    $report.Add($Text)
}

Log-Output "========================================================" "Cyan"
Log-Output "   rath15-htpc Remote Login & Access Diagnostic Report   " "Cyan"
Log-Output "   Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  " "Cyan"
Log-Output "========================================================" "Cyan"

# 1. Operating System Edition
$os = Get-CimInstance Win32_OperatingSystem
Log-Output "`n[1] OPERATING SYSTEM" "Yellow"
Log-Output "  Caption: $($os.Caption)"
Log-Output "  Version: $($os.Version) (Build $($os.BuildNumber))"

$isHome = $os.Caption -like "*Home*"
if ($isHome) {
    Log-Output "  [!] WARNING: Windows Home edition detected!" "Red"
    Log-Output "      Windows Home does NOT natively support incoming Remote Desktop (RDP) connections." "Red"
    Log-Output "      OpenSSH or third-party remote tools (VNC, Moonlight, RustDesk) must be used instead." "Yellow"
} else {
    Log-Output "  [OK] Windows Pro/Enterprise edition detected. RDP host capability is supported." "Green"
}

# 2. Remote Desktop (RDP) Configuration
Log-Output "`n[2] REMOTE DESKTOP (RDP) STATUS" "Yellow"
$rdpSvc = Get-Service TermService -ErrorAction SilentlyContinue
if ($rdpSvc) {
    Log-Output "  Service (TermService): $($rdpSvc.Status) (Startup: $($rdpSvc.StartType))"
} else {
    Log-Output "  Service (TermService): Not Installed" "Red"
}

$fDeny = (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -ErrorAction SilentlyContinue).fDenyTSConnections
if ($fDeny -eq 0) {
    Log-Output "  RDP Connections (fDenyTSConnections): 0 (Enabled / Allowed)" "Green"
} elseif ($fDeny -eq 1) {
    Log-Output "  RDP Connections (fDenyTSConnections): 1 (DISABLED / BLOCKED)" "Red"
} else {
    Log-Output "  RDP Connections: Unknown / Not configured" "Yellow"
}

$nla = (Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -ErrorAction SilentlyContinue).UserAuthentication
if ($nla -eq 1) {
    Log-Output "  Network Level Authentication (NLA): Enabled (Requires valid credentials before GUI)" "Green"
} elseif ($nla -eq 0) {
    Log-Output "  Network Level Authentication (NLA): Disabled" "Yellow"
}

# 3. Windows Hello Passwordless Policy
Log-Output "`n[3] WINDOWS HELLO PASSWORDLESS POLICY" "Yellow"
$pwless = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Passwordless\Device" -Name "DevicePasswordLessBuildVersion" -ErrorAction SilentlyContinue).DevicePasswordLessBuildVersion
if ($pwless -eq 2) {
    Log-Output "  [!] Passwordless Lockdown: ACTIVE (DevicePasswordLessBuildVersion = 2)" "Red"
    Log-Output "      Windows disables remote password logins when Passwordless Hello is enforced." "Red"
    Log-Output "      Fix: Disable 'Only allow Windows Hello sign-in for Microsoft accounts' in Settings." "Yellow"
} elseif ($pwless -eq 0) {
    Log-Output "  [OK] Passwordless Lockdown: Inactive (Standard password authentication allowed)" "Green"
} else {
    Log-Output "  Passwordless setting: Not set or default ($pwless)" "Cyan"
}

# 4. OpenSSH Server Status
Log-Output "`n[4] OPENSSH SERVER STATUS" "Yellow"
$sshCap = Get-WindowsCapability -Online -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "OpenSSH.Server*" }
if ($sshCap) {
    Log-Output "  Capability: $($sshCap.Name) - State: $($sshCap.State)"
} else {
    Log-Output "  Capability: OpenSSH.Server not found" "Yellow"
}

$sshSvc = Get-Service sshd -ErrorAction SilentlyContinue
if ($sshSvc) {
    Log-Output "  Service (sshd): $($sshSvc.Status) (Startup: $($sshSvc.StartType))" "Cyan"
} else {
    Log-Output "  Service (sshd): Not installed" "Yellow"
}

# 5. User Accounts & Group Memberships
Log-Output "`n[5] USER ACCOUNTS & PRIVILEGES" "Yellow"
try {
    $users = Get-LocalUser -ErrorAction SilentlyContinue
    foreach ($u in $users) {
        $status = if ($u.Enabled) { "Enabled" } else { "Disabled" }
        $pwReq = if ($u.PasswordRequired) { "PasswordRequired" } else { "NO Password Required" }
        Log-Output "  User: $($u.Name) | Status: $status | $pwReq | LastLogon: $($u.LastLogon)"
    }

    Log-Output "`n  Group: Administrators" "Cyan"
    $admins = Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue
    foreach ($m in $admins) {
        Log-Output "    - $($m.Name) ($($m.ObjectClass))"
    }

    Log-Output "`n  Group: Remote Desktop Users" "Cyan"
    $rdpUsers = Get-LocalGroupMember -Group "Remote Desktop Users" -ErrorAction SilentlyContinue
    if ($rdpUsers) {
        foreach ($m in $rdpUsers) {
            Log-Output "    - $($m.Name) ($($m.ObjectClass))"
        }
    } else {
        Log-Output "    (No users explicitly in Remote Desktop Users; Administrators are permitted by default)" "Gray"
    }
} catch {
    Log-Output "  [!] Could not query local users: $($_.Exception.Message)" "Yellow"
}

# 6. Network Configuration & Firewall Profiles
Log-Output "`n[6] NETWORK CONFIGURATION & FIREWALL" "Yellow"
$netProfiles = Get-NetConnectionProfile -ErrorAction SilentlyContinue
foreach ($np in $netProfiles) {
    $pColor = if ($np.NetworkCategory -eq "Private") { "Green" } else { "Red" }
    Log-Output "  Interface: $($np.InterfaceAlias) | Category: $($np.NetworkCategory) | IPv4: $($np.IPv4Address)" $pColor
    if ($np.NetworkCategory -ne "Private") {
        Log-Output "    [!] Warning: Network category is not 'Private'. Windows Firewall blocks RDP on Public networks!" "Red"
    }
}

$rdpRules = Get-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq "True" -and $_.Direction -eq "Inbound" }
Log-Output "`n  Active Inbound Remote Desktop Firewall Rules: $($rdpRules.Count)" "Cyan"

$sshRules = Get-NetFirewallRule -Name "*ssh*" -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq "True" -and $_.Direction -eq "Inbound" }
Log-Output "  Active Inbound SSH Firewall Rules: $($sshRules.Count)" "Cyan"

Log-Output "`n========================================================" "Cyan"
Log-Output "Diagnostic complete. Report saved to:" "Cyan"
Log-Output "  $reportPath" "Green"
Log-Output "========================================================" "Cyan"

$report | Set-Content -Path $reportPath -Encoding utf8 -Force

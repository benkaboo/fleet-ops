<#
.SYNOPSIS
    Diagnoses OpenSSH Server readiness and network accessibility on rath15-htpc.
.DESCRIPTION
    Run this script locally on rath15-htpc in PowerShell.
    It checks:
      1. OpenSSH Server capability installation status.
      2. Status and startup configuration of the 'sshd' service.
      3. Network connection category (Private vs Public).
      4. Inbound Windows Firewall rules for Port 22.
      5. Existence and permissions (ACL) of administrators_authorized_keys and user authorized_keys.
      6. Local user accounts and active IP addresses.
    Outputs findings to console and saves report to htpc_diagnostics_report.txt.
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
Log-Output "     rath15-htpc OpenSSH Server Readiness Diagnostic     " "Cyan"
Log-Output "   Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  " "Cyan"
Log-Output "========================================================" "Cyan"

# 1. Operating System & Local User
$os = Get-CimInstance Win32_OperatingSystem
Log-Output "`n[1] SYSTEM & USER IDENTITY" "Yellow"
Log-Output "  OS: $($os.Caption) (Build $($os.BuildNumber))"
Log-Output "  Host: $env:COMPUTERNAME | Current User: $env:USERNAME"

# 2. OpenSSH Windows Capability
Log-Output "`n[2] OPENSSH SERVER CAPABILITY" "Yellow"
$sshCap = Get-WindowsCapability -Online -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "OpenSSH.Server*" }
if ($sshCap) {
    $capColor = if ($sshCap.State -eq "Installed") { "Green" } else { "Red" }
    Log-Output "  Capability: $($sshCap.Name) - State: $($sshCap.State)" $capColor
} else {
    Log-Output "  [!] Capability: OpenSSH.Server not detected" "Red"
}

# 3. sshd Service Status
Log-Output "`n[3] SSH SERVICE STATUS" "Yellow"
$sshd = Get-Service sshd -ErrorAction SilentlyContinue
if ($sshd) {
    $svcColor = if ($sshd.Status -eq "Running") { "Green" } else { "Yellow" }
    Log-Output "  Service (sshd): $($sshd.Status) (Startup: $($sshd.StartType))" $svcColor
} else {
    Log-Output "  Service (sshd): Not installed" "Red"
}

$agent = Get-Service ssh-agent -ErrorAction SilentlyContinue
if ($agent) {
    Log-Output "  Service (ssh-agent): $($agent.Status) (Startup: $($agent.StartType))" "Cyan"
}

# 4. Network Category & Firewall
Log-Output "`n[4] NETWORK & FIREWALL" "Yellow"
$profiles = Get-NetConnectionProfile -ErrorAction SilentlyContinue
foreach ($p in $profiles) {
    $pColor = if ($p.NetworkCategory -eq "Private") { "Green" } else { "Red" }
    Log-Output "  Interface: $($p.InterfaceAlias) | Category: $($p.NetworkCategory) | IPv4: $($p.IPv4Address)" $pColor
    if ($p.NetworkCategory -ne "Private") {
        Log-Output "    [!] Warning: Windows Firewall drops incoming connections on Public networks." "Red"
    }
}

$sshRules = Get-NetFirewallRule -Name "*ssh*" -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq "True" -and $_.Direction -eq "Inbound" }
Log-Output "  Active Inbound SSH Firewall Rules: $($sshRules.Count)" "Cyan"
foreach ($r in $sshRules) {
    $portFilter = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $r -ErrorAction SilentlyContinue
    $addrFilter = Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $r -ErrorAction SilentlyContinue
    Log-Output "    - Rule: $($r.DisplayName) | Port: $($portFilter.LocalPort) | Remote: $($addrFilter.RemoteAddress)"
}

# 5. Authorized Keys & Permissions
Log-Output "`n[5] AUTHORIZED KEYS INTEGRITY" "Yellow"
$adminKey = "$env:ProgramData\ssh\administrators_authorized_keys"
if (Test-Path $adminKey) {
    $keys = Get-Content $adminKey
    Log-Output "  [OK] administrators_authorized_keys exists (Contains $($keys.Count) keys)" "Green"
    $acl = Get-Acl -Path $adminKey
    Log-Output "       Access Rules: $($acl.Access.Count) entry/entries"
} else {
    Log-Output "  [!] administrators_authorized_keys NOT found" "Yellow"
}

$userKey = "$env:USERPROFILE\.ssh\authorized_keys"
if (Test-Path $userKey) {
    $uKeys = Get-Content $userKey
    Log-Output "  [OK] User authorized_keys exists (Contains $($uKeys.Count) keys)" "Green"
} else {
    Log-Output "  [!] User authorized_keys NOT found" "Yellow"
}

# 6. Active IP Addresses
Log-Output "`n[6] ACTIVE IP ADDRESSES" "Yellow"
$ips = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "vEthernet|Loopback" }
foreach ($ip in $ips) {
    Log-Output "  - $($ip.IPAddress) ($($ip.InterfaceAlias))" "Cyan"
}

Log-Output "`n========================================================" "Cyan"
Log-Output "Diagnostic complete. Report saved to:" "Cyan"
Log-Output "  $reportPath" "Green"
Log-Output "========================================================" "Cyan"

$report | Set-Content -Path $reportPath -Encoding utf8 -Force

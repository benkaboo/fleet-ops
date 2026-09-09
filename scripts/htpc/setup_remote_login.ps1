<#
.SYNOPSIS
    Configures secure Remote Desktop (RDP) and OpenSSH Server on rath15-htpc.
.DESCRIPTION
    Run this script locally on rath15-htpc as Administrator in PowerShell.
    
    Security & Configuration Highlights:
      1. Network Level Authentication (NLA) is strictly enforced for RDP.
      2. Windows Firewall rules are restricted to the Local Subnet (192.168.68.0/24 / LocalSubnet).
      3. Network category is verified and switched to 'Private' to allow trusted LAN traffic.
      4. Disables the Windows Hello "Passwordless" lock so network password auth succeeds.
      5. (Optional) Prompts to configure a dedicated local admin user for deterministic login.
      6. (Optional) Installs and hardens OpenSSH Server with Ben''s workstation Ed25519 public key.

.PARAMETER EnableRDP
    Enables and configures Remote Desktop (default: $true).

.PARAMETER EnableSSH
    Installs and configures OpenSSH Server with public key authentication (default: $true).

.PARAMETER CreateLocalUser
    Switch to create a dedicated local administrative user account for reliable RDP/SSH.
#>

[CmdletBinding()]
param(
    [switch]$EnableRDP = $true,
    [switch]$EnableSSH = $true,
    [switch]$CreateLocalUser
)

# 0. Check Administrator Privilege
$isAdmin = [bool]((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
if (-not $isAdmin) {
    Write-Error "This setup script MUST be run as Administrator! Please right-click PowerShell and select 'Run as administrator'."
    exit 1
}

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "   rath15-htpc Secure Remote Login Setup Wizard         " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# 1. Ensure Active Network Profile is 'Private'
Write-Host "`n[1/5] Verifying Network Connection Profile..." -ForegroundColor Cyan
$profiles = Get-NetConnectionProfile
foreach ($p in $profiles) {
    if ($p.NetworkCategory -ne "Private") {
        Write-Host "  -> Changing interface '$($p.InterfaceAlias)' from $($p.NetworkCategory) to Private..." -ForegroundColor Yellow
        Set-NetConnectionProfile -InterfaceIndex $p.InterfaceIndex -NetworkCategory Private
        Write-Host "  -> Interface '$($p.InterfaceAlias)' set to Private." -ForegroundColor Green
    } else {
        Write-Host "  -> Interface '$($p.InterfaceAlias)' is already set to Private." -ForegroundColor Green
    }
}

# 2. Configure Remote Desktop (RDP)
if ($EnableRDP) {
    Write-Host "`n[2/5] Configuring Remote Desktop (RDP)..." -ForegroundColor Cyan
    
    # Check OS Edition
    $os = Get-CimInstance Win32_OperatingSystem
    if ($os.Caption -like "*Home*") {
        Write-Host "  [!] Warning: Windows Home edition does not natively support RDP hosting." -ForegroundColor Red
        Write-Host "      Proceeding with OpenSSH and network configuration instead." -ForegroundColor Yellow
    } else {
        # Enable RDP in registry
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
        
        # Enforce Network Level Authentication (NLA) for security
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -Value 1
        
        # Ensure TermService is Running & Automatic
        Set-Service -Name TermService -StartupType Automatic
        Start-Service -Name TermService -ErrorAction SilentlyContinue
        
        # Disable Windows Hello Passwordless lockdown (allows network password authentication)
        $pwlessKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Passwordless\Device"
        if (Test-Path $pwlessKey) {
            Set-ItemProperty -Path $pwlessKey -Name "DevicePasswordLessBuildVersion" -Value 0 -ErrorAction SilentlyContinue
        }
        
        # Configure Inbound Firewall: Restrict to LocalSubnet for security
        $rdpRule = Get-NetFirewallRule -DisplayName "Remote Desktop - User Mode (TCP-In)" -ErrorAction SilentlyContinue
        if ($rdpRule) {
            Set-NetFirewallRule -Name $rdpRule.Name -Enabled True -Profile Private -RemoteAddress LocalSubnet
            Write-Host "  -> RDP Firewall Rule configured (Restricted to LocalSubnet)." -ForegroundColor Green
        } else {
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
            Write-Host "  -> Remote Desktop firewall group enabled." -ForegroundColor Green
        }
        
        Write-Host "  -> Remote Desktop (RDP) successfully enabled with NLA and LocalSubnet scoping." -ForegroundColor Green
    }
}

# 3. Configure OpenSSH Server (Key-Based)
if ($EnableSSH) {
    Write-Host "`n[3/5] Configuring OpenSSH Server..." -ForegroundColor Cyan
    
    # Install OpenSSH.Server if missing
    $sshCap = Get-WindowsCapability -Online | Where-Object { $_.Name -like "OpenSSH.Server*" }
    if ($sshCap.State -ne "Installed") {
        Write-Host "  -> Installing OpenSSH Server capability (this may take 1-2 minutes)..." -ForegroundColor Yellow
        Add-WindowsCapability -Online -Name $sshCap.Name | Out-Null
        Write-Host "  -> OpenSSH Server capability installed." -ForegroundColor Green
    } else {
        Write-Host "  -> OpenSSH Server is already installed." -ForegroundColor Green
    }
    
    # Configure and start sshd service
    Set-Service -Name sshd -StartupType Automatic
    Start-Service -Name sshd -ErrorAction SilentlyContinue
    
    # Configure Firewall rule restricted to LocalSubnet
    $sshFw = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
    if ($sshFw) {
        Set-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -Enabled True -Profile Private -RemoteAddress LocalSubnet
    } else {
        New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -Profile Private -RemoteAddress LocalSubnet | Out-Null
    }
    Write-Host "  -> OpenSSH firewall rule configured (Port 22, LocalSubnet only)." -ForegroundColor Green
    
    # Install Ben's Workstation Public Key for Passwordless Admin SSH
    $adminKeyFile = "$env:ProgramData\ssh\administrators_authorized_keys"
    $benPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIZ770T1Rk509xop3YRfue50lvOY9fPd0w8jckwNWYi3 ben.bmaslen@gmail.com"
    $sshDir = "$env:ProgramData\ssh"
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    }
    
    # Append key if not present
    $currentKeys = if (Test-Path $adminKeyFile) { Get-Content $adminKeyFile } else { @() }
    if ($currentKeys -notcontains $benPubKey) {
        Add-Content -Path $adminKeyFile -Value $benPubKey -Force
        Write-Host "  -> Added Ben's Workstation Ed25519 public key to administrators_authorized_keys." -ForegroundColor Green
    }
    
    # Fix strict Windows OpenSSH ACL on administrators_authorized_keys (SYSTEM & Administrators only)
    $acl = Get-Acl -Path $adminKeyFile
    $acl.SetAccessRuleProtection($true, $false) # Disable inheritance, remove existing
    $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\SYSTEM", "FullControl", "Allow")
    $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administrators", "FullControl", "Allow")
    $acl.SetAccessRule($systemRule)
    $acl.SetAccessRule($adminRule)
    Set-Acl -Path $adminKeyFile -AclObject $acl
    Write-Host "  -> Hardened file permissions on administrators_authorized_keys." -ForegroundColor Green
}

# 4. Optional / Recommended: Dedicated Local Account
Write-Host "`n[4/5] Dedicated Local Admin Account..." -ForegroundColor Cyan
if ($CreateLocalUser -or $Host.UI.RawUI) {
    $promptUser = $false
    if (-not $CreateLocalUser) {
        $choice = Read-Host "Would you like to create a dedicated local admin account (e.g. 'htpc-admin') for 100% reliable RDP login? (y/N)"
        if ($choice -eq "y" -or $choice -eq "Y") { $promptUser = $true }
    } else {
        $promptUser = $true
    }

    if ($promptUser) {
        $username = Read-Host "Enter username [default: htpc-admin]"
        if ([string]::IsNullOrWhiteSpace($username)) { $username = "htpc-admin" }
        
        $password = Read-Host -AsSecureString "Enter secure password for $username"
        
        $existing = Get-LocalUser -Name $username -ErrorAction SilentlyContinue
        if ($null -eq $existing) {
            New-LocalUser -Name $username -Password $password -FullName "HTPC Remote Admin" -Description "Dedicated account for secure remote administration" -PasswordNeverExpires | Out-Null
            Write-Host "  -> Created local user '$username'." -ForegroundColor Green
        } else {
            Set-LocalUser -Name $username -Password $password
            Write-Host "  -> Updated password for existing local user '$username'." -ForegroundColor Green
        }
        
        Add-LocalGroupMember -Group "Administrators" -Member $username -ErrorAction SilentlyContinue
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $username -ErrorAction SilentlyContinue
        Write-Host "  -> Added '$username' to Administrators and Remote Desktop Users groups." -ForegroundColor Green
        Write-Host "  -> Login from workstation as: .\$username or rath15-htpc\$username" -ForegroundColor Yellow
    }
}

# 5. Verification & Summary
Write-Host "`n[5/5] Setup Summary & Connection Instructions" -ForegroundColor Cyan
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "vEthernet|Loopback" -and $_.IPAddress -like "192.168*" } | Select-Object -First 1).IPAddress

Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Target Host IP: $ip" -ForegroundColor Green
Write-Host "1. Remote Desktop (RDP):" -ForegroundColor Cyan
Write-Host "   - Command: mstsc /v:$ip"
Write-Host "   - If using Microsoft Account: MicrosoftAccount\ben.maslen@outlook.com + Outlook password"
Write-Host "   - If using Local Account: .\<username> + local password"
Write-Host "2. OpenSSH (Command Line):" -ForegroundColor Cyan
Write-Host "   - Command: ssh $ip"
Write-Host "   - Or with explicit key: ssh -i ~/.ssh/id_ed25519 <username>@$ip"
Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
Write-Host "`nSetup completed successfully." -ForegroundColor Green

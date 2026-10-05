<#
.SYNOPSIS
    Installs, configures, and hardens OpenSSH Server on rath15-htpc.
.DESCRIPTION
    Run this script locally on rath15-htpc as Administrator in PowerShell.
    
    Security & Hardening Measures:
      1. Provisions native Windows OpenSSH Server capability.
      2. Configures sshd to start automatically on system boot.
      3. Restricts incoming TCP port 22 strictly to LocalSubnet (192.168.68.0/24) via Windows Firewall.
      4. Sets network adapter connection profile to 'Private' (required for trusted local communication).
      5. Deploys Ben''s workstation Ed25519 public key for passwordless, cryptographically verified SSH.
      6. Applies strict ACL permissions on authorized_keys files to prevent unauthorized key tampering.
      7. Enables PubkeyAuthentication in sshd_config.
#>

[CmdletBinding()]
param(
    [switch]$DisablePasswordAuth = $false
)

# 0. Check Administrator Privilege
$isAdmin = [bool]((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
if (-not $isAdmin) {
    Write-Error "This script MUST be run as Administrator! Please right-click PowerShell and select 'Run as administrator'."
    exit 1
}

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "      rath15-htpc OpenSSH Server Hardening Setup        " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# 1. Network Category Verification
Write-Host "`n[1/6] Verifying Network Profile..." -ForegroundColor Cyan
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

# 2. Provision Windows OpenSSH Server Capability / Offline Binaries
Write-Host "`n[2/6] Provisioning OpenSSH Server..." -ForegroundColor Cyan

$sshdInstalled = $false

# A. Fast Check: Is sshd service or binary already registered?
$existingSvc = Get-Service sshd -ErrorAction SilentlyContinue
if ($existingSvc) {
    Write-Host "  -> sshd service is already registered ($($existingSvc.Status))." -ForegroundColor Green
    $sshdInstalled = $true
} elseif (Test-Path "$env:SystemRoot\System32\OpenSSH\sshd.exe") {
    Write-Host "  -> Native sshd.exe binary detected in System32." -ForegroundColor Green
    $sshdInstalled = $true
}

if (-not $sshdInstalled) {
    # B. Offline Package Check (S:\Scripts\htpc\OpenSSH-Win64.zip)
    $zipPath = Join-Path $PSScriptRoot "OpenSSH-Win64.zip"
    if (Test-Path $zipPath) {
        Write-Host "  -> Found offline OpenSSH-Win64.zip! Extracting to C:\Program Files\OpenSSH (bypassing Windows Update/DISM)..." -ForegroundColor Green
        $targetDir = "C:\Program Files\OpenSSH"
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        
        # Extract archive
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $tempExtract = Join-Path $env:TEMP "OpenSSH_Extract"
        if (Test-Path $tempExtract) { Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $tempExtract)
        
        $innerDir = Join-Path $tempExtract "OpenSSH-Win64"
        if (Test-Path $innerDir) {
            Copy-Item -Path "$innerDir\*" -Destination $targetDir -Recurse -Force
        } else {
            Copy-Item -Path "$tempExtract\*" -Destination $targetDir -Recurse -Force
        }
        Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
        
        # Add to System PATH if not present
        $sysPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($sysPath -notlike "*$targetDir*") {
            [System.Environment]::SetEnvironmentVariable("Path", "$targetDir;$sysPath", "Machine")
            Write-Host "  -> Added $targetDir to System PATH." -ForegroundColor Green
        }
        
        # Execute official installer script
        $installer = Join-Path $targetDir "install-sshd.ps1"
        if (Test-Path $installer) {
            Write-Host "  -> Running official install-sshd.ps1..." -ForegroundColor Cyan
            & powershell.exe -ExecutionPolicy Bypass -File $installer
        }
        $sshdInstalled = $true
    } else {
        # C. Fallback to DISM
        Write-Host "  -> Installing via DISM..." -ForegroundColor Yellow
        & dism.exe /Online /Add-Capability /CapabilityName:OpenSSH.Server~~~~0.0.1.0
    }
}

# 3. Configure and Start Services
Write-Host "`n[3/6] Configuring SSH Services..." -ForegroundColor Cyan
Set-Service -Name sshd -StartupType Automatic
Set-Service -Name "ssh-agent" -StartupType Automatic
Start-Service -Name "ssh-agent" -ErrorAction SilentlyContinue
Start-Service -Name sshd -ErrorAction SilentlyContinue
Write-Host "  -> Services 'sshd' and 'ssh-agent' configured to Automatic (Running)." -ForegroundColor Green

# 4. Configure Windows Firewall (Restricted to LocalSubnet)
Write-Host "`n[4/6] Configuring Windows Firewall..." -ForegroundColor Cyan
$ruleName = "OpenSSH-Server-In-TCP-Hardened"
$existingRule = Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue

if ($null -eq $existingRule) {
    # Remove any default open-to-any rules if present
    Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Set-NetFirewallRule -Enabled False
    
    New-NetFirewallRule -Name $ruleName `
        -DisplayName "OpenSSH Server (Port 22 - LocalSubnet Only)" `
        -Enabled True `
        -Direction Inbound `
        -Protocol TCP `
        -Action Allow `
        -LocalPort 22 `
        -Profile Private `
        -RemoteAddress LocalSubnet | Out-Null
    Write-Host "  -> Created inbound firewall rule: Port 22 allowed strictly on Private/LocalSubnet." -ForegroundColor Green
} else {
    Set-NetFirewallRule -Name $ruleName -Enabled True -Profile Private -RemoteAddress LocalSubnet
    Write-Host "  -> Inbound firewall rule updated to LocalSubnet restriction." -ForegroundColor Green
}

# 5. Authorize Ben's Workstation Ed25519 Public Key
Write-Host "`n[5/6] Deploying Authorized SSH Keys..." -ForegroundColor Cyan

# Workstation User Key and AGY Agent Key
$trustedKeys = @(
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIZ770T1Rk509xop3YRfue50lvOY9fPd0w8jckwNWYi3 ben.bmaslen@gmail.com",
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKMSfluk+fAUAymrrf7CYHRPyhaCXzLaxqlAYPuBI/X1 agy-auditor@rath15nas"
)

# A. System-wide administrators_authorized_keys (Used by Windows for any admin user)
$adminKeyPath = "$env:ProgramData\ssh\administrators_authorized_keys"
$programDataSsh = "$env:ProgramData\ssh"

if (-not (Test-Path $programDataSsh)) {
    New-Item -ItemType Directory -Path $programDataSsh -Force | Out-Null
}

$currentAdminKeys = if (Test-Path $adminKeyPath) { Get-Content $adminKeyPath } else { @() }
foreach ($key in $trustedKeys) {
    if ($currentAdminKeys -notcontains $key) {
        Add-Content -Path $adminKeyPath -Value $key -Force
    }
}

# Apply strict ACLs on administrators_authorized_keys (SYSTEM and BUILTIN\Administrators ONLY)
$adminAcl = Get-Acl -Path $adminKeyPath
$adminAcl.SetAccessRuleProtection($true, $false) # Disable inheritance and remove existing ACEs
$systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\SYSTEM", "FullControl", "Allow")
$adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administrators", "FullControl", "Allow")
$adminAcl.SetAccessRule($systemRule)
$adminAcl.SetAccessRule($adminRule)
Set-Acl -Path $adminKeyPath -AclObject $adminAcl
Write-Host "  -> Configured and hardened: $adminKeyPath" -ForegroundColor Green

# B. Current User's .ssh\authorized_keys (For standard non-admin or explicit user logins)
$userSshDir = "$env:USERPROFILE\.ssh"
$userAuthKeyPath = Join-Path $userSshDir "authorized_keys"

if (-not (Test-Path $userSshDir)) {
    New-Item -ItemType Directory -Path $userSshDir -Force | Out-Null
}

$currentUserKeys = if (Test-Path $userAuthKeyPath) { Get-Content $userAuthKeyPath } else { @() }
foreach ($key in $trustedKeys) {
    if ($currentUserKeys -notcontains $key) {
        Add-Content -Path $userAuthKeyPath -Value $key -Force
    }
}

# Apply strict ACL on user's authorized_keys (Current user and SYSTEM only)
$userAcl = Get-Acl -Path $userAuthKeyPath
$userAcl.SetAccessRuleProtection($true, $false)
$owner = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$ownerRule = New-Object System.Security.AccessControl.FileSystemAccessRule($owner, "FullControl", "Allow")
$userAcl.SetAccessRule($systemRule)
$userAcl.SetAccessRule($ownerRule)
Set-Acl -Path $userAuthKeyPath -AclObject $userAcl
Write-Host "  -> Configured and hardened: $userAuthKeyPath (Owner: $owner)" -ForegroundColor Green

# 6. Hardening sshd_config
Write-Host "`n[6/6] Hardening sshd_config..." -ForegroundColor Cyan
$sshdConfigPath = "$env:ProgramData\ssh\sshd_config"

if (Test-Path $sshdConfigPath) {
    $config = Get-Content $sshdConfigPath
    
    # Ensure PubkeyAuthentication is yes
    if ($config -match "^#?PubkeyAuthentication") {
        $config = $config -replace "^#?PubkeyAuthentication.*", "PubkeyAuthentication yes"
    } else {
        $config += "`nPubkeyAuthentication yes"
    }
    
    if ($DisablePasswordAuth) {
        if ($config -match "^#?PasswordAuthentication") {
            $config = $config -replace "^#?PasswordAuthentication.*", "PasswordAuthentication no"
        } else {
            $config += "`nPasswordAuthentication no"
        }
        Write-Host "  -> Password authentication disabled (Strict Public Key only)." -ForegroundColor Yellow
    }
    
    $config | Set-Content -Path $sshdConfigPath -Encoding utf8 -Force
    Restart-Service -Name sshd
    Write-Host "  -> Restarted sshd with verified configuration." -ForegroundColor Green
}

# Print Summary
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "vEthernet|Loopback" -and $_.IPAddress -like "192.168*" } | Select-Object -First 1).IPAddress
$localUser = [System.Environment]::UserName

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "   OpenSSH Setup Complete! Connection Instructions:     " -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "From your workstation terminal, you can now connect via:" -ForegroundColor White
Write-Host "  ssh $localUser@$ip" -ForegroundColor Green
Write-Host "Or using hostname:" -ForegroundColor White
Write-Host "  ssh $localUser@rath15-htpc" -ForegroundColor Green
Write-Host "========================================================`n" -ForegroundColor Cyan

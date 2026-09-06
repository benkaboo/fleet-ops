# ==============================================================================
# Deploy Windows-Optimized Samba Share to Proxmox Host
# Run directly from PowerShell on your Windows laptop
# ==============================================================================

[CmdletBinding()]
param()

Clear-Host
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "    Deploy Windows-Optimized Samba Share to Proxmox Host" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Press [Enter] to accept the suggested default values in brackets.`n"

# 1. Gather Variables
$DefaultHost = "192.168.68.169"
$RemoteHost = Read-Host "Enter Proxmox Host IP / Hostname [$DefaultHost]"
if ([string]::IsNullOrWhiteSpace($RemoteHost)) { $RemoteHost = $DefaultHost }

$DefaultSshUser = "bjm"
$SshUser = Read-Host "Enter SSH Admin Username [$DefaultSshUser]"
if ([string]::IsNullOrWhiteSpace($SshUser)) { $SshUser = $DefaultSshUser }

$DefaultSharePath = "/mnt/data/@simba"
$SharePath = Read-Host "Enter Path of Directory/Subvolume on Proxmox [$DefaultSharePath]"
if ([string]::IsNullOrWhiteSpace($SharePath)) { $SharePath = $DefaultSharePath }

$DefaultShareName = "simba"
$ShareName = Read-Host "Enter Windows Share Name [$DefaultShareName]"
if ([string]::IsNullOrWhiteSpace($ShareName)) { $ShareName = $DefaultShareName }

$DefaultSambaUser = "bjm"
$SambaUser = Read-Host "Enter Samba Username [$DefaultSambaUser]"
if ([string]::IsNullOrWhiteSpace($SambaUser)) { $SambaUser = $DefaultSambaUser }

$DefaultNetbios = "RATH15NAS"
$NetbiosName = Read-Host "Enter NetBIOS Server Name [$DefaultNetbios]"
if ([string]::IsNullOrWhiteSpace($NetbiosName)) { $NetbiosName = $DefaultNetbios }

$DefaultWorkgroup = "WORKGROUP"
$Workgroup = Read-Host "Enter Windows Workgroup [$DefaultWorkgroup]"
if ([string]::IsNullOrWhiteSpace($Workgroup)) { $Workgroup = $DefaultWorkgroup }

$GuestInput = Read-Host "Allow Guest / Anonymous Read Access? (y/N) [N]"
$AllowGuest = if ($GuestInput -match "^[yY]") { "yes" } else { "no" }

$WsddInput = Read-Host "Install WSDD for automatic Windows Network Discovery? (Y/n) [Y]"
$InstallWsdd = if ($WsddInput -match "^[nN]") { "no" } else { "yes" }

Write-Host "`n----------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "Deployment Summary:" -ForegroundColor Yellow
Write-Host "  * Host:             $SshUser@$RemoteHost"
Write-Host "  * Share Path:       $SharePath"
Write-Host "  * Share Name:       $ShareName"
Write-Host "  * Samba User:       $SambaUser"
Write-Host "  * NetBIOS Name:     $NetbiosName"
Write-Host "  * Workgroup:        $Workgroup"
Write-Host "  * Guest Access:     $AllowGuest"
Write-Host "  * Enable WSDD:      $InstallWsdd"
Write-Host "----------------------------------------------------------------------" -ForegroundColor Yellow

$Confirm = Read-Host "Proceed with deployment to $RemoteHost? (Y/n) [Y]"
if ($Confirm -match "^[nN]") {
    Write-Host "[-] Deployment cancelled." -ForegroundColor Red
    exit 0
}

# 2. Execute on Remote Host
Write-Host "`n[*] Connecting to $RemoteHost via SSH to configure Samba..." -ForegroundColor Green

$RemoteScript = @"
set -euo pipefail

# Ensure target path exists
if [ ! -d '$SharePath' ]; then
    mkdir -p '$SharePath'
fi

chown -R '$SambaUser:$SambaUser' '$SharePath'
chmod 775 '$SharePath'

# Install packages
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq samba
if [ '$InstallWsdd' = 'yes' ]; then
    apt-get install -y -qq wsdd || true
fi

# Backup existing smb.conf
[ -f /etc/samba/smb.conf ] && cp /etc/samba/smb.conf /etc/samba/smb.conf.bak_\$(date +%Y%m%d%H%M%S)

# Write smb.conf
cat << 'SMBEOF' > /etc/samba/smb.conf
[global]
   workgroup = $Workgroup
   server string = $NetbiosName File Server
   netbios name = $NetbiosName
   security = user

   server min protocol = SMB3
   server multi channel support = yes
   aio read size = 1
   aio write size = 1
   use sendfile = yes

   store dos attributes = yes
   ea support = yes
   case sensitive = auto
   preserve case = yes
   short preserve case = yes

   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file

[$ShareName]
   comment = $ShareName Network Storage
   path = $SharePath
   browseable = yes
   read only = no
   guest ok = $AllowGuest
   valid users = $SambaUser
   create mask = 0664
   directory mask = 0775
   force user = $SambaUser
   force group = $SambaUser
   vfs objects = streams_xattr acl_xattr
SMBEOF

testparm -s /etc/samba/smb.conf > /dev/null
systemctl enable --now smbd.service
systemctl restart smbd.service

if [ '$InstallWsdd' = 'yes' ] && systemctl list-unit-files | grep -q wsdd.service; then
    systemctl enable --now wsdd.service
    systemctl restart wsdd.service
fi

echo ''
echo '=== Set Samba Password for $SambaUser ==='
smbpasswd -a '$SambaUser'
"@

# Run remotely using interactive SSH (supports sudo password and smbpasswd prompts)
ssh -t "$SshUser@$RemoteHost" "sudo bash -c `"$RemoteScript`""

Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "    Deployment Finished!" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "You can now connect from Windows File Explorer:"
Write-Host "  \\$RemoteHost\$ShareName" -ForegroundColor Yellow
Write-Host "  \\$NetbiosName\$ShareName" -ForegroundColor Yellow
Write-Host "`nMap as a network drive in PowerShell:"
Write-Host "  New-PSDrive -Name 'S' -PSProvider FileSystem -Root '\\$RemoteHost\$ShareName' -Persist" -ForegroundColor Gray

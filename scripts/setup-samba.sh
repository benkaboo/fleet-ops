#!/usr/bin/env bash
# ==============================================================================
# Setup Windows-Optimized Samba Share on Proxmox / Debian
# Interactive deployment script prompting for network & share variables
# ==============================================================================

set -euo pipefail

# Ensure script is run with sudo/root privileges
if [[ $EUID -ne 0 ]]; then
    echo "[!] This script must be run as root or with sudo."
    echo "    Usage: sudo bash $0"
    exit 1
fi

echo "======================================================================"
echo "    Windows-Optimized Samba Share Setup for Btrfs Storage"
echo "======================================================================"
echo "Press [Enter] to accept the suggested default values in brackets."
echo ""

# ------------------------------------------------------------------------------
# 1. Variable Prompts
# ------------------------------------------------------------------------------

# Share Path
DEFAULT_SHARE_PATH="/mnt/data/@simba"
read -r -p "Enter path of the directory/subvolume to share [$DEFAULT_SHARE_PATH]: " INPUT_PATH
SHARE_PATH="${INPUT_PATH:-$DEFAULT_SHARE_PATH}"

# Share Name
DEFAULT_SHARE_NAME="simba"
read -r -p "Enter Windows Share Name [$DEFAULT_SHARE_NAME]: " INPUT_SHARE_NAME
SHARE_NAME="${INPUT_SHARE_NAME:-$DEFAULT_SHARE_NAME}"

# Authorized Samba Username
DEFAULT_USER="${SUDO_USER:-bjm}"
read -r -p "Enter Linux/Samba user who will own and access this share [$DEFAULT_USER]: " INPUT_USER
SAMBA_USER="${INPUT_USER:-$DEFAULT_USER}"

# Verify or create Linux user if not exists
if ! id "$SAMBA_USER" &>/dev/null; then
    echo "[!] User '$SAMBA_USER' does not exist on this host."
    read -r -p "Would you like to create system user '$SAMBA_USER'? (y/N): " CREATE_USER
    if [[ "${CREATE_USER,,}" =~ ^(y|yes)$ ]]; then
        useradd -m -s /bin/bash "$SAMBA_USER"
        echo "[+] User '$SAMBA_USER' created."
    else
        echo "[-] Aborting setup."
        exit 1
    fi
fi

# NetBIOS Name
DEFAULT_NETBIOS="RATH15NAS"
read -r -p "Enter NetBIOS Server Name for Windows Discovery [$DEFAULT_NETBIOS]: " INPUT_NETBIOS
NETBIOS_NAME="${INPUT_NETBIOS:-$DEFAULT_NETBIOS}"

# Windows Workgroup
DEFAULT_WORKGROUP="WORKGROUP"
read -r -p "Enter Windows Workgroup [$DEFAULT_WORKGROUP]: " INPUT_WORKGROUP
WORKGROUP="${INPUT_WORKGROUP:-$DEFAULT_WORKGROUP}"

# Guest Access
read -r -p "Allow anonymous / guest read-only access? (y/N) [N]: " INPUT_GUEST
ALLOW_GUEST="no"
if [[ "${INPUT_GUEST,,}" =~ ^(y|yes)$ ]]; then
    ALLOW_GUEST="yes"
fi

# Install WSDD for Windows Network Discovery
read -r -p "Install & enable WSDD for automatic Windows Explorer discovery? (Y/n) [Y]: " INPUT_WSDD
INSTALL_WSDD="yes"
if [[ "${INPUT_WSDD,,}" =~ ^(n|no)$ ]]; then
    INSTALL_WSDD="no"
fi

echo ""
echo "----------------------------------------------------------------------"
echo "Configuration Summary:"
echo "  * Share Path:       $SHARE_PATH"
echo "  * Share Name:       [$SHARE_NAME]"
echo "  * Primary User:     $SAMBA_USER"
echo "  * NetBIOS Name:     $NETBIOS_NAME"
echo "  * Workgroup:        $WORKGROUP"
echo "  * Guest Access:     $ALLOW_GUEST"
echo "  * Enable WSDD:      $INSTALL_WSDD"
echo "----------------------------------------------------------------------"
read -r -p "Proceed with this configuration? (Y/n) [Y]: " CONFIRM
if [[ "${CONFIRM,,}" =~ ^(n|no)$ ]]; then
    echo "[-] Operation cancelled."
    exit 0
fi

# ------------------------------------------------------------------------------
# 2. Prerequisites & Path Verification
# ------------------------------------------------------------------------------

# Ensure target share path exists
if [[ ! -d "$SHARE_PATH" ]]; then
    echo "[*] Path '$SHARE_PATH' does not exist. Creating directory..."
    mkdir -p "$SHARE_PATH"
fi

# Set proper ownership and permissions
echo "[*] Setting ownership of '$SHARE_PATH' to $SAMBA_USER:$SAMBA_USER..."
chown -R "$SAMBA_USER:$SAMBA_USER" "$SHARE_PATH"
chmod 775 "$SHARE_PATH"

# Install Samba packages
echo "[*] Installing Samba and dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq samba

if [[ "$INSTALL_WSDD" == "yes" ]]; then
    echo "[*] Installing wsdd (Web Services Dynamic Discovery)..."
    apt-get install -y -qq wsdd || {
        echo "[!] Warning: 'wsdd' package not available in standard repository. Continuing..."
        INSTALL_WSDD="no"
    }
fi

# ------------------------------------------------------------------------------
# 3. Configure /etc/samba/smb.conf
# ------------------------------------------------------------------------------

BACKUP_FILE="/etc/samba/smb.conf.bak_$(date +%Y%m%d%H%M%S)"
if [[ -f /etc/samba/smb.conf ]]; then
    echo "[*] Backing up existing smb.conf to $BACKUP_FILE..."
    cp /etc/samba/smb.conf "$BACKUP_FILE"
fi

echo "[*] Writing Windows-optimized Samba configuration..."
cat << EOF > /etc/samba/smb.conf
# ==============================================================================
# Samba Configuration - Windows Client Optimized
# Generated on: $(date)
# ==============================================================================

[global]
   workgroup = $WORKGROUP
   server string = $NETBIOS_NAME File Server
   netbios name = $NETBIOS_NAME
   security = user

   # Windows protocol & multi-channel performance
   server min protocol = SMB3
   server multi channel support = yes
   aio read size = 1
   aio write size = 1
   use sendfile = yes

   # Native Windows attributes, extended attributes & filename compatibility
   store dos attributes = yes
   ea support = yes
   case sensitive = auto
   preserve case = yes
   short preserve case = yes

   # Logging
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file
   panic action = /usr/share/samba/panic-action %d

# ==============================================================================
# Shares
# ==============================================================================

[$SHARE_NAME]
   comment = $SHARE_NAME Network Storage
   path = $SHARE_PATH
   browseable = yes
   read only = no
   guest ok = $ALLOW_GUEST
   valid users = $SAMBA_USER
   create mask = 0664
   directory mask = 0775
   force user = $SAMBA_USER
   force group = $SAMBA_USER
   vfs objects = streams_xattr acl_xattr
EOF

# ------------------------------------------------------------------------------
# 4. Validate and Restart Services
# ------------------------------------------------------------------------------

echo "[*] Validating smb.conf syntax..."
testparm -s /etc/samba/smb.conf > /dev/null

echo "[*] Enabling and restarting Samba systemd services..."
systemctl enable --now smbd.service
systemctl restart smbd.service

if [[ "$INSTALL_WSDD" == "yes" ]]; then
    systemctl enable --now wsdd.service
    systemctl restart wsdd.service
fi

# ------------------------------------------------------------------------------
# 5. Set Samba User Password
# ------------------------------------------------------------------------------

echo ""
echo "======================================================================"
echo "    Set Password for Samba User: $SAMBA_USER"
echo "======================================================================"
echo "This password will be used when connecting from Windows clients."
smbpasswd -a "$SAMBA_USER"

# ------------------------------------------------------------------------------
# 6. Output Connection Instructions
# ------------------------------------------------------------------------------

HOST_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "======================================================================"
echo "    Samba Share Setup Complete!"
echo "======================================================================"
echo ""
echo "To connect from your Windows PCs:"
echo "  1. Open Windows File Explorer."
echo "  2. Enter one of the following in the address bar:"
echo "       \\\\$HOST_IP\\$SHARE_NAME"
echo "       \\\\$NETBIOS_NAME\\$SHARE_NAME"
echo ""
echo "  3. Enter credentials:"
echo "       Username: $SAMBA_USER"
echo "       Password: (the password you just entered)"
echo ""
if [[ "$INSTALL_WSDD" == "yes" ]]; then
    echo "  4. Network Discovery:"
    echo "       '$NETBIOS_NAME' will also appear automatically under 'Network' in File Explorer."
fi
echo "======================================================================"

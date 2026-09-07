#!/usr/bin/env bash
# ==============================================================================
# Setup Dedicated HTPC Samba User and [Media] Share
# Target Host: rath15nas (run as root or with sudo)
# ==============================================================================

set -euo pipefail

MEDIA_PATH="/mnt/simba/Media"
SAMBA_CONF="/etc/samba/smb.conf"
HTPC_USER="htpc"
PRIMARY_ADMIN="bjm"

echo "======================================================================"
echo "    Provision Dedicated HTPC Samba User & [Media] Share"
echo "======================================================================"

# 1. Entry Condition Checks
if [[ $EUID -ne 0 ]]; then
    echo "[!] Error: This script must be run as root or with sudo."
    echo "    Usage: sudo bash $0"
    exit 1
fi

if [[ ! -d "$MEDIA_PATH" ]]; then
    echo "[!] Error: Media directory '$MEDIA_PATH' does not exist."
    exit 1
fi

if [[ ! -f "$SAMBA_CONF" ]]; then
    echo "[!] Error: Samba configuration file '$SAMBA_CONF' not found."
    exit 1
fi

# 2. Provision Linux User 'htpc' (Least Privilege)
echo "[*] Ensuring Linux user '$HTPC_USER' exists..."
if ! id "$HTPC_USER" &>/dev/null; then
    # Create system user without interactive shell or home directory, member of 'users'
    useradd -M -s /usr/sbin/nologin -g users "$HTPC_USER"
    echo "[+] Created locked-down system user '$HTPC_USER' (shell: /usr/sbin/nologin)."
else
    echo "[i] User '$HTPC_USER' already exists."
fi

# 3. Configure Media Directory SetGID & Permissions
echo "[*] Ensuring group ownership and directory SetGID on '$MEDIA_PATH'..."
chgrp -R "$PRIMARY_ADMIN" "$MEDIA_PATH"
chmod g+s "$MEDIA_PATH"
if [[ -d "$MEDIA_PATH/Movies" ]]; then chmod g+s "$MEDIA_PATH/Movies"; fi
if [[ -d "$MEDIA_PATH/TV Shows" ]]; then chmod g+s "$MEDIA_PATH/TV Shows"; fi
if [[ -d "$MEDIA_PATH/Music" ]]; then chmod g+s "$MEDIA_PATH/Music"; fi

# 4. Set Samba Password for htpc
echo ""
echo "======================================================================"
echo "    Set Samba Password for user '$HTPC_USER'"
echo "======================================================================"
echo "Please enter the password for the HTPC when prompted:"
smbpasswd -a "$HTPC_USER"
smbpasswd -e "$HTPC_USER"
echo "[+] Samba account for '$HTPC_USER' enabled."

# 5. Configure [Media] Share in smb.conf
echo ""
echo "[*] Updating '$SAMBA_CONF'..."

# Create timestamped backup
BACKUP_FILE="${SAMBA_CONF}.bak.$(date +%Y%m%d_%H%M%S)"
cp "$SAMBA_CONF" "$BACKUP_FILE"
echo "[+] Backup created: $BACKUP_FILE"

if grep -q "^\[Media\]" "$SAMBA_CONF"; then
    echo "[!] Notice: [Media] section already exists in $SAMBA_CONF. Skipping append."
else
    cat << 'EOF' >> "$SAMBA_CONF"

[Media]
    comment = Media Library (Movies, TV Shows, Music)
    path = /mnt/simba/Media
    browseable = yes
    read only = no
    guest ok = no
    valid users = bjm, htpc
    force user = bjm
    force group = bjm
    force create mode = 0664
    force directory mode = 0775
    vfs objects = btrfs acl_xattr
    map acl inherit = yes
    store dos attributes = yes
EOF
    echo "[+] Added [Media] share to $SAMBA_CONF."
fi

# 6. Validate & Reload Samba
echo "[*] Validating Samba configuration with testparm..."
testparm -s "$SAMBA_CONF" >/dev/null
echo "[+] Samba syntax valid."

echo "[*] Reloading Samba service..."
systemctl reload smbd.service
echo "[+] smbd.service reloaded successfully."

echo ""
echo "======================================================================"
echo "    Setup Complete!"
echo "======================================================================"
echo "Windows HTPC Connection Details:"
echo "  * Share UNC Path: \\rath15nas\Media (or \\192.168.68.169\Media)"
echo "  * Username:       htpc"
echo "  * Permissions:    Read / Write (Movies, TV Shows, Music)"
echo "======================================================================"

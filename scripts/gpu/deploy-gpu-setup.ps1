# ==============================================================================
# GPU Acceleration Deployment Orchestrator
# Automates NVIDIA setup across Host, LXC, and Docker runtime
# Run directly from PowerShell on your Windows workstation
# ==============================================================================

[CmdletBinding()]
param(
    [string]$HostIp = "192.168.68.169",      # rath15nas (Proxmox Host)
    [string]$LxcIp = "192.168.68.175",       # LXC 920 (services)
    [string]$SshUser = "bjm"
)

Clear-Host
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "    NVIDIA GPU Acceleration Deployment (GeForce GTX 1080 Ti)" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Targets:" -ForegroundColor Gray
Write-Host "  * Proxmox Host: $HostIp (rath15nas)" -ForegroundColor Gray
Write-Host "  * Services LXC: $LxcIp (LXC 920)" -ForegroundColor Gray
Write-Host "======================================================================" -ForegroundColor Cyan

$Script01 = Join-Path $PSScriptRoot "01-host-nvidia-setup.sh"
$Script02 = Join-Path $PSScriptRoot "02-pve-lxc-passthrough.sh"
$Script03 = Join-Path $PSScriptRoot "03-container-docker-setup.sh"

# ------------------------------------------------------------------------------
# STEP 1: Host Driver Setup
# ------------------------------------------------------------------------------
Write-Host "`n[STEP 1/3] Deploying NVIDIA Drivers to Proxmox Host ($HostIp)..." -ForegroundColor Yellow
if (-not (Test-Path $Script01)) { Write-Error "Missing $Script01"; exit 1 }

scp "$Script01" "${SshUser}@${HostIp}:/tmp/01-host-nvidia-setup.sh"
Write-Host "[*] Executing 01-host-nvidia-setup.sh with sudo on $HostIp..." -ForegroundColor Green
Write-Host "[*] Enter sudo password when prompted:" -ForegroundColor Yellow
ssh -t "${SshUser}@${HostIp}" "sudo bash /tmp/01-host-nvidia-setup.sh; rm -f /tmp/01-host-nvidia-setup.sh"

Write-Host "`n----------------------------------------------------------------------" -ForegroundColor Magenta
Write-Host "[!] PROXMOX HOST REBOOT REQUIRED" -ForegroundColor Magenta
Write-Host "    The host must now be rebooted to unload 'nouveau' and load 'nvidia'." -ForegroundColor Magenta
Write-Host "    Run on host: sudo reboot" -ForegroundColor Magenta
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta

$rebootConfirm = Read-Host "Has the Proxmox host finished rebooting and is back online? (y/n)"
if ($rebootConfirm -ne 'y') {
    Write-Host "Exiting. Re-run this script after host reboot to continue with Step 2 & 3." -ForegroundColor Yellow
    exit 0
}

# ------------------------------------------------------------------------------
# STEP 2: LXC Passthrough
# ------------------------------------------------------------------------------
Write-Host "`n[STEP 2/3] Configuring GPU Passthrough in LXC 920 (/etc/pve/lxc/920.conf)..." -ForegroundColor Yellow
if (-not (Test-Path $Script02)) { Write-Error "Missing $Script02"; exit 1 }

scp "$Script02" "${SshUser}@${HostIp}:/tmp/02-pve-lxc-passthrough.sh"
Write-Host "[*] Executing 02-pve-lxc-passthrough.sh with sudo on $HostIp..." -ForegroundColor Green
ssh -t "${SshUser}@${HostIp}" "sudo bash /tmp/02-pve-lxc-passthrough.sh; rm -f /tmp/02-pve-lxc-passthrough.sh"

# ------------------------------------------------------------------------------
# STEP 3: Container & Docker Runtime Setup
# ------------------------------------------------------------------------------
Write-Host "`n[STEP 3/3] Installing NVIDIA Container Toolkit in LXC 920 ($LxcIp)..." -ForegroundColor Yellow
if (-not (Test-Path $Script03)) { Write-Error "Missing $Script03"; exit 1 }

scp "$Script03" "${SshUser}@${LxcIp}:/tmp/03-container-docker-setup.sh"
Write-Host "[*] Executing 03-container-docker-setup.sh on $LxcIp..." -ForegroundColor Green
ssh -t "${SshUser}@${LxcIp}" "sudo bash /tmp/03-container-docker-setup.sh; rm -f /tmp/03-container-docker-setup.sh"

Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "    GPU Infrastructure Deployment Completed Successfully!" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Next Step: In homelab-stacks, switch immich-machine-learning to CUDA image." -ForegroundColor Green

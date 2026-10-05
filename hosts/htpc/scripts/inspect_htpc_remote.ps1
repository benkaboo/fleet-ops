[CmdletBinding()]
param(
    [string]$TargetHost = "rath15-htpc",
    [string]$OutputPath = ""
)

if (-not $OutputPath) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $baseDir = Split-Path -Parent $scriptDir
    $OutputPath = Join-Path $baseDir "reports\baseline_inventory.md"
}

$collectorScriptPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "remote_collector.ps1"
if (-not (Test-Path $collectorScriptPath)) {
    Write-Error "Could not find $collectorScriptPath"
    exit 1
}

$reportDir = Split-Path -Parent $OutputPath
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

Write-Host "Connecting to $TargetHost over SSH to run remote telemetry discovery..." -ForegroundColor Cyan

$rawJson = Get-Content -Path $collectorScriptPath -Raw | ssh -o BatchMode=yes $TargetHost "powershell -NoProfile -Command -"

$jsonLines = $rawJson -split "`r?`n" | Where-Object { $_ -notmatch '^#< CLIXML' -and $_ -notmatch '^<Objs ' -and $_ -notmatch '^<Obj ' -and $_ -notmatch '^\s*<' }
$cleanJson = ($jsonLines -join "`n").Trim()

$data = $cleanJson | ConvertFrom-Json

if (-not $data) {
    Write-Error "Failed to receive valid JSON from $TargetHost"
    exit 1
}

Write-Host "Received telemetry from $($data.ComputerName). Building baseline markdown..." -ForegroundColor Green

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("# HTPC Host Baseline Inventory ($($data.ComputerName))")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine("Target Node: $($data.ComputerName) | OS: $($data.OSCaption)")
[void]$sb.AppendLine("")

# 1. System & Hardware
[void]$sb.AppendLine("## 1. System & Hardware Baseline")
[void]$sb.AppendLine("| Parameter | Value |")
[void]$sb.AppendLine("| :--- | :--- |")
[void]$sb.AppendLine("| **Host Name** | $($data.ComputerName) |")
[void]$sb.AppendLine("| **OS Caption** | $($data.OSCaption) ($($data.OSArchitecture)) |")
[void]$sb.AppendLine("| **OS Version / Build** | $($data.OSVersion) (Build $($data.OSBuild)) |")
[void]$sb.AppendLine("| **Last Boot Time** | $($data.LastBootUpTime) (Uptime: $($data.UptimeDays) days) |")
[void]$sb.AppendLine("| **Motherboard** | $($data.Motherboard) |")
[void]$sb.AppendLine("| **Processor** | $($data.CPU) |")
[void]$sb.AppendLine("| **Total RAM** | $($data.TotalRAM_GB) GB (Free: $($data.FreeRAM_GB) GB, Used: $($data.UsedRAM_GB) GB) |")
[void]$sb.AppendLine("")

# 2. Graphics & Audio
[void]$sb.AppendLine("## 2. Graphics & Audio Subsystem")
[void]$sb.AppendLine("### Video Controllers (GPUs)")
[void]$sb.AppendLine("| Device Name | Driver Version | Video Mode | Dedicated VRAM |")
[void]$sb.AppendLine("| :--- | :--- | :--- | :--- |")
foreach ($g in $data.GPUs) {
    [void]$sb.AppendLine("| $($g.Name) | $($g.DriverVersion) | $($g.VideoModeDescription) | $($g.RAM_GB) GB |")
}
[void]$sb.AppendLine("")

[void]$sb.AppendLine("### Audio Devices")
[void]$sb.AppendLine("| Device Name | Manufacturer | Status |")
[void]$sb.AppendLine("| :--- | :--- | :--- |")
foreach ($a in $data.Audio) {
    [void]$sb.AppendLine("| $($a.Name) | $($a.Manufacturer) | $($a.Status) |")
}
[void]$sb.AppendLine("")

# 3. Storage Topology
[void]$sb.AppendLine("## 3. Storage Topology")
[void]$sb.AppendLine("### Physical Disks")
[void]$sb.AppendLine("| Disk | Friendly Name | Media Type | Bus Type | Size (GB) | Health | Status |")
[void]$sb.AppendLine("| :--- | :--- | :--- | :--- | :--- | :--- | :--- |")
foreach ($d in $data.Disks) {
    [void]$sb.AppendLine("| $($d.DeviceId) | $($d.FriendlyName) | $($d.MediaType) | $($d.BusType) | $($d.SizeGB) | $($d.HealthStatus) | $($d.OperationalStatus) |")
}
[void]$sb.AppendLine("")

[void]$sb.AppendLine("### Local Volumes & Mounted Drives")
[void]$sb.AppendLine("| Drive | Root | Total (GB) | Used (GB) | Free (GB) | % Free |")
[void]$sb.AppendLine("| :--- | :--- | :--- | :--- | :--- | :--- |")
foreach ($v in $data.Volumes) {
    [void]$sb.AppendLine("| $($v.Name) | $($v.Root) | $($v.TotalGB) | $($v.UsedGB) | $($v.FreeGB) | $($v.PctFree)% |")
}
[void]$sb.AppendLine("")

if ($data.SmbMappings) {
    [void]$sb.AppendLine("### Network SMB Mappings")
    [void]$sb.AppendLine("| Local | Remote Target | Status |")
    [void]$sb.AppendLine("| :--- | :--- | :--- |")
    foreach ($m in $data.SmbMappings) {
        [void]$sb.AppendLine("| $($m.LocalPath) | $($m.RemotePath) | $($m.Status) |")
    }
    [void]$sb.AppendLine("")
}

# 4. Network Configuration
[void]$sb.AppendLine("## 4. Network Configuration")
[void]$sb.AppendLine("| Interface | IP Address | Subnet Prefix |")
[void]$sb.AppendLine("| :--- | :--- | :--- |")
foreach ($net in $data.NetworkIPs) {
    [void]$sb.AppendLine("| $($net.InterfaceAlias) | $($net.IPAddress) | /$($net.PrefixLength) |")
}
[void]$sb.AppendLine("")

# 5. Media & Remote Services
[void]$sb.AppendLine("## 5. Media Runtimes & Autostart Software")
[void]$sb.AppendLine("### Running Media / Remote Processes")
if ($data.MediaProcesses) {
    [void]$sb.AppendLine("| Process Name | PID | RAM (MB) |")
    [void]$sb.AppendLine("| :--- | :--- | :--- |")
    foreach ($p in $data.MediaProcesses) {
        [void]$sb.AppendLine("| $($p.Name) | $($p.Id) | $($p.RAM_MB) |")
    }
} else {
    [void]$sb.AppendLine("*(No active media player processes detected in current snapshot)*")
}
[void]$sb.AppendLine("")

[void]$sb.AppendLine("### Autostart Entries (HKCU - User Scope)")
[void]$sb.AppendLine("| Name | Command |")
[void]$sb.AppendLine("| :--- | :--- |")
foreach ($r in $data.RunHKCU) {
    [void]$sb.AppendLine("| $($r.Name) | ``$($r.Value)`` |")
}
[void]$sb.AppendLine("")

[void]$sb.AppendLine("### Autostart Entries (HKLM - Machine Scope)")
[void]$sb.AppendLine("| Name | Command |")
[void]$sb.AppendLine("| :--- | :--- |")
foreach ($r in $data.RunHKLM) {
    [void]$sb.AppendLine("| $($r.Name) | ``$($r.Value)`` |")
}
[void]$sb.AppendLine("")

# 6. Remote Services & Firewall
[void]$sb.AppendLine("## 6. Remote Access Services")
[void]$sb.AppendLine("| Service | Status | Startup Type | Protocol / Port |")
[void]$sb.AppendLine("| :--- | :--- | :--- | :--- |")
[void]$sb.AppendLine("| OpenSSH (`sshd`) | $($data.SshService.Status) | $($data.SshService.StartType) | Port 22 (TCP) |")
[void]$sb.AppendLine("| Remote Desktop (`TermService`) | $($data.RdpService.Status) | $($data.RdpService.StartType) | Port 3389 (TCP) |")
[void]$sb.AppendLine("")

# 7. System Health Summary
[void]$sb.AppendLine("## 7. System Health & Error Telemetry (Last 7 Days)")
[void]$sb.AppendLine("| Metric | Count | Status |")
[void]$sb.AppendLine("| :--- | :--- | :--- |")
[void]$sb.AppendLine("| **System Event Errors** | $($data.EventSysErrors7d) | $(if ($data.EventSysErrors7d -gt 50) { 'Elevated' } else { 'Normal' }) |")
[void]$sb.AppendLine("| **Application Event Errors** | $($data.EventAppErrors7d) | $(if ($data.EventAppErrors7d -gt 50) { 'Elevated' } else { 'Normal' }) |")
[void]$sb.AppendLine("| **Kernel-Power 41 (Unexpected Shutdowns)** | $($data.EventKernelPower41_7d) | $(if ($data.EventKernelPower41_7d -gt 0) { 'Flagged' } else { 'Clean' }) |")
[void]$sb.AppendLine("| **WHEA Hardware Errors** | $($data.EventWHEA7d) | $(if ($data.EventWHEA7d -gt 0) { 'HARDWARE WARNING' } else { 'Clean (0)' }) |")
[void]$sb.AppendLine("")

$sb.ToString() | Set-Content -Path $OutputPath -Encoding utf8 -Force
Write-Host "Baseline successfully written to $OutputPath" -ForegroundColor Green

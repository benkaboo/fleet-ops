<#
.SYNOPSIS
    Non-invasive, read-only system inventory and architecture discovery script.
.DESCRIPTION
    Collects hardware, OS, disk topology, developer runtimes, WSL distributions,
    and cache footprints without modifying any files or settings.
    Outputs a structured markdown report to reports/baseline_inventory.md.
#>

[CmdletBinding()]
param (
    [string]$OutputPath = ""
)

$ErrorActionPreference = 'SilentlyContinue'

if (-not $OutputPath) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
    $baseDir = if ($scriptDir) { Split-Path -Parent $scriptDir } else { (Get-Location).Path }
    $OutputPath = Join-Path -Path $baseDir -ChildPath "reports\baseline_inventory.md"
}

function Format-Code([string]$val) {
    return '`' + $val + '`'
}

# Ensure output directory exists
$ReportDir = Split-Path -Path $OutputPath -Parent
if (-not (Test-Path $ReportDir)) {
    New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
}

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("# Workstation Host Baseline Inventory")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine("Host Machine: $env:COMPUTERNAME | User: $env:USERNAME")
[void]$sb.AppendLine("")

# --- 1. OS & System Summary ---
Write-Host "Collecting OS and hardware specs..." -ForegroundColor Cyan
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1

$totalRamGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
$freeRamGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)

[void]$sb.AppendLine("## 1. System & Hardware Baseline")
[void]$sb.AppendLine("| Parameter | Value |")
[void]$sb.AppendLine("| :--- | :--- |")
[void]$sb.AppendLine("| **OS Caption** | $($os.Caption) ($($os.OSArchitecture)) |")
[void]$sb.AppendLine("| **OS Version / Build** | $($os.Version) (Build $($os.BuildNumber)) |")
[void]$sb.AppendLine("| **Last Boot Time** | $($os.LastBootUpTime) |")
[void]$sb.AppendLine("| **Processor** | $($cpu.Name) ($($cpu.NumberOfCores) Cores / $($cpu.NumberOfLogicalProcessors) Threads) |")
[void]$sb.AppendLine("| **Total RAM** | $totalRamGB GB (Free: $freeRamGB GB) |")
[void]$sb.AppendLine("| **Manufacturer / Model** | $($cs.Manufacturer) - $($cs.Model) |")
[void]$sb.AppendLine("")

# --- 2. Storage & Disks ---
Write-Host "Collecting disk topology..." -ForegroundColor Cyan
[void]$sb.AppendLine("## 2. Storage Topology")
[void]$sb.AppendLine("| Drive | Volume Name | File System | Total Size (GB) | Free Space (GB) | % Free |")
[void]$sb.AppendLine("| :--- | :--- | :--- | :--- | :--- | :--- |")

$disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
foreach ($d in $disks) {
    $totalGB = [math]::Round($d.Size / 1GB, 2)
    $freeGB = [math]::Round($d.FreeSpace / 1GB, 2)
    $pctFree = if ($d.Size -gt 0) { [math]::Round(($d.FreeSpace / $d.Size) * 100, 1) } else { 0 }
    [void]$sb.AppendLine("| $($d.DeviceID) | $($d.VolumeName) | $($d.FileSystem) | $totalGB | $freeGB | $pctFree% |")
}
[void]$sb.AppendLine("")

# --- 3. Developer Runtimes & Tooling ---
Write-Host "Scanning developer toolchains..." -ForegroundColor Cyan
[void]$sb.AppendLine("## 3. Developer Toolchains & CLI Utilities")
[void]$sb.AppendLine("| Tool | Detected | Version / Path |")
[void]$sb.AppendLine("| :--- | :--- | :--- |")

$tools = @(
    @{ Name = "Git"; Cmd = "git"; Args = "--version" },
    @{ Name = "Python"; Cmd = "python"; Args = "--version" },
    @{ Name = "Python 3"; Cmd = "python3"; Args = "--version" },
    @{ Name = "Node.js"; Cmd = "node"; Args = "--version" },
    @{ Name = "npm"; Cmd = "npm"; Args = "--version" },
    @{ Name = "Cargo / Rust"; Cmd = "cargo"; Args = "--version" },
    @{ Name = "Go"; Cmd = "go"; Args = "version" },
    @{ Name = "Docker CLI"; Cmd = "docker"; Args = "--version" },
    @{ Name = "Winget"; Cmd = "winget"; Args = "--version" },
    @{ Name = "Scoop"; Cmd = "scoop"; Args = "--version" },
    @{ Name = "Chocolatey"; Cmd = "choco"; Args = "--version" },
    @{ Name = "Antigravity CLI (agy)"; Cmd = "agy"; Args = "--version" }
)

foreach ($t in $tools) {
    $found = Get-Command -Name $t.Cmd -ErrorAction SilentlyContinue
    if ($found) {
        $vOutput = ""
        try {
            $proc = Start-Process -FilePath $t.Cmd -ArgumentList $t.Args -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\tool_check.tmp" -RedirectStandardError "$env:TEMP\tool_check_err.tmp"
            $proc.WaitForExit(3000) | Out-Null
            if (Test-Path "$env:TEMP\tool_check.tmp") {
                $vOutput = (Get-Content "$env:TEMP\tool_check.tmp" -Raw -ErrorAction SilentlyContinue).Trim()
                Remove-Item "$env:TEMP\tool_check.tmp" -Force -ErrorAction SilentlyContinue
            }
            if (-not $vOutput -and (Test-Path "$env:TEMP\tool_check_err.tmp")) {
                $vOutput = (Get-Content "$env:TEMP\tool_check_err.tmp" -Raw -ErrorAction SilentlyContinue).Trim()
                Remove-Item "$env:TEMP\tool_check_err.tmp" -Force -ErrorAction SilentlyContinue
            }
        } catch {
            $vOutput = $found.Source
        }
        if (-not $vOutput) { $vOutput = $found.Source }
        $vOutput = ($vOutput -split "`r?`n")[0]
        $codeBlock = Format-Code $vOutput
        [void]$sb.AppendLine("| $($t.Name) | Yes | $codeBlock |")
    } else {
        [void]$sb.AppendLine("| $($t.Name) | No | Not in PATH |")
    }
}
[void]$sb.AppendLine("")

# --- 4. WSL & Virtualization ---
Write-Host "Checking WSL distributions..." -ForegroundColor Cyan
[void]$sb.AppendLine("## 4. Virtualization & Subsystems")
$wslCmd = Get-Command "wsl" -ErrorAction SilentlyContinue
if ($wslCmd) {
    $wslList = wsl.exe --list --verbose 2>&1
    [void]$sb.AppendLine('```text')
    foreach ($line in $wslList) {
        $cleanLine = "$line" -replace "`0", ""
        if ($cleanLine.Trim().Length -gt 0) {
            [void]$sb.AppendLine($cleanLine)
        }
    }
    [void]$sb.AppendLine('```')
} else {
    [void]$sb.AppendLine("*WSL is not installed or not in PATH.*")
}
[void]$sb.AppendLine("")

# --- 5. Network Adapters ---
Write-Host "Querying network interfaces..." -ForegroundColor Cyan
[void]$sb.AppendLine("## 5. Active Network Adapters")
[void]$sb.AppendLine("| Interface Alias | IP Address | Description | Status |")
[void]$sb.AppendLine("| :--- | :--- | :--- | :--- |")

$adapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" }
foreach ($ip in $adapters) {
    $adapter = Get-NetAdapter -InterfaceIndex $ip.InterfaceIndex -ErrorAction SilentlyContinue
    $desc = if ($adapter) { $adapter.InterfaceDescription } else { "N/A" }
    $status = if ($adapter) { $adapter.Status } else { "Unknown" }
    [void]$sb.AppendLine("| $($ip.InterfaceAlias) | $($ip.IPAddress) | $desc | $status |")
}
[void]$sb.AppendLine("")

# --- 6. Cache Footprints (Safe measurement) ---
Write-Host "Measuring developer cache footprints..." -ForegroundColor Cyan
[void]$sb.AppendLine("## 6. Known Cache & Temporary Space Usage")
[void]$sb.AppendLine("| Cache Category | Path | Estimated Size (MB) | Status |")
[void]$sb.AppendLine("| :--- | :--- | :--- | :--- |")

$cachePaths = @(
    @{ Name = "User Temp (%TEMP%)"; Path = $env:TEMP },
    @{ Name = "npm Cache"; Path = "$env:LOCALAPPDATA\npm-cache" },
    @{ Name = "pip Cache"; Path = "$env:LOCALAPPDATA\pip\cache" },
    @{ Name = "Docker Desktop Data"; Path = "$env:LOCALAPPDATA\Docker" },
    @{ Name = "VS Code Cache"; Path = "$env:APPDATA\Code\Cache" },
    @{ Name = "Antigravity CLI Logs"; Path = "$env:USERPROFILE\.gemini\antigravity-cli\logs" }
)

foreach ($c in $cachePaths) {
    $cCode = Format-Code $c.Path
    if (Test-Path $c.Path) {
        $sizeMB = [math]::Round(((Get-ChildItem -Path $c.Path -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB), 2)
        [void]$sb.AppendLine("| $($c.Name) | $cCode | $sizeMB MB | Present |")
    } else {
        [void]$sb.AppendLine("| $($c.Name) | $cCode | 0 MB | Not Present |")
    }
}
[void]$sb.AppendLine("")

# --- 7. Autostart Items ---
Write-Host "Scanning autostart registry entries..." -ForegroundColor Cyan
[void]$sb.AppendLine("## 7. Autostart Registry Entries")
[void]$sb.AppendLine("| Scope | Name | Command |")
[void]$sb.AppendLine("| :--- | :--- | :--- |")

$runKeys = @(
    @{ Scope = "HKCU (User)"; Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" },
    @{ Scope = "HKLM (System)"; Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" }
)

foreach ($rk in $runKeys) {
    if (Test-Path $rk.Path) {
        $props = Get-ItemProperty -Path $rk.Path -ErrorAction SilentlyContinue
        foreach ($prop in $props.PSObject.Properties) {
            if ($prop.Name -notmatch "^PS.*") {
                $cmdCode = Format-Code ([string]$prop.Value)
                [void]$sb.AppendLine("| $($rk.Scope) | $($prop.Name) | $cmdCode |")
            }
        }
    }
}
[void]$sb.AppendLine("")

# Save to disk
[System.IO.File]::WriteAllText($OutputPath, $sb.ToString())
Write-Host "`nBaseline inventory complete! Report written to: $OutputPath" -ForegroundColor Green

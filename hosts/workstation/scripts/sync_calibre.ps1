<#
.SYNOPSIS
    Calibre Library Synchronization Script (Workstation -> NAS Media Storage)
.DESCRIPTION
    Safely copies/syncs D:\Calibre_Library_Main to S:\Media\Books (or \\RATH15NAS\simba\Media\Books)
    using Robocopy. Designed for daily background automation and manual on-demand execution.
    
    CRITICAL SAFETY BEHAVIOR:
    - Additive-only sync (/E). Does NOT purge or delete files from the destination.
    - Manually uploaded books on Calibre-Web/NAS are preserved and never deleted.
    - Excludes older files (/XO) to avoid overwriting newer files on the NAS.
.PARAMETER DryRun
    Simulates the synchronization without modifying any files on the destination.
.PARAMETER Silent
    Suppresses console output; records all operations exclusively to the log file.
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Silent
)

$ErrorActionPreference = "Stop"

# Configuration
$sourcePath = "D:\Calibre_Library_Main"
$destDrivePath = "S:\Media\Books"
$destUncPath = "\\RATH15NAS\simba\Media\Books"
$logDir = "C:\ProgramData\calibre-sync"
$logFile = "$logDir\sync.log"

# Ensure log directory exists
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# 1. Log Rotation (Keep under 5 MB)
if (Test-Path $logFile) {
    try {
        $logLength = (Get-Item $logFile).Length
        if ($logLength -gt 5MB) {
            Move-Item -Path $logFile -Destination "$logFile.old" -Force
        }
    } catch {
        # Continue if rotation check fails
    }
}

function Write-SyncLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $line -Encoding UTF8
    if (-not $Silent) {
        switch ($Level) {
            "ERROR" { Write-Host $line -ForegroundColor Red }
            "WARN"  { Write-Host $line -ForegroundColor Yellow }
            "SUCCESS" { Write-Host $line -ForegroundColor Green }
            default { Write-Host $line }
        }
    }
}

Write-SyncLog "=================================================="
Write-SyncLog "Starting Calibre Library Additive Sync"
if ($DryRun) {
    Write-SyncLog "[DRY-RUN MODE ENABLED - No files will be modified]" "WARN"
}

# 2. Pre-Flight Validation: Source
if (-not (Test-Path $sourcePath)) {
    Write-SyncLog "Source path not found: $sourcePath" "ERROR"
    exit 1
}

# 3. Pre-Flight Validation: Target Path Resolution
$targetPath = $null
if (Test-Path $destDrivePath) {
    $targetPath = $destDrivePath
    Write-SyncLog "Target resolved via mapped drive: $targetPath"
} elseif (Test-Path $destUncPath) {
    $targetPath = $destUncPath
    Write-SyncLog "Target resolved via UNC share: $targetPath"
} else {
    Write-SyncLog "Destination unreachable at both '$destDrivePath' and '$destUncPath'. Verify network or S: drive access." "ERROR"
    exit 2
}

# 4. Check for Running Calibre Application
$calibreProcesses = Get-Process -Name "*calibre*" -ErrorAction SilentlyContinue
if ($calibreProcesses) {
    Write-SyncLog "Calibre is currently open. Proceeding with safe retries (/R:2 /W:2)." "WARN"
}

# 5. Build Robocopy Command Arguments
# /E: Copy subdirectories, including empty ones (additive only, NO /MIR or /PURGE)
# /XO: Exclude older files (protects newer edits or uploads on destination)
# /FFT: Assume FAT File Times (2s granularity for SMB compatibility)
# /R:2 /W:2: 2 retries, 2-second wait on locked files
# /MT:8: Multi-threaded copying
# /NP /NDL: Clean non-verbose logging
# /XF /XD: Exclude desktop/thumbs artifacts and recycle bins
$robocopyArgs = @(
    "`"$sourcePath`"",
    "`"$targetPath`"",
    "/E",
    "/XO",
    "/FFT",
    "/R:2",
    "/W:2",
    "/MT:8",
    "/NP",
    "/NDL",
    "/XF", "thumbs.db", "desktop.ini",
    "/XD", "`$RECYCLE.BIN", "System Volume Information"
)

if ($DryRun) {
    $robocopyArgs += "/L"
}

$tempRoboLog = "$logDir\robocopy_last.log"
$robocopyArgs += "/LOG:`"$tempRoboLog`""

Write-SyncLog "Executing Robocopy from '$sourcePath' to '$targetPath'..."
$process = Start-Process -FilePath "robocopy.exe" -ArgumentList $robocopyArgs -NoNewWindow -Wait -PassThru
$exitCode = $process.ExitCode

# Append Robocopy summary lines to the primary sync log
if (Test-Path $tempRoboLog) {
    $summary = Get-Content -Path $tempRoboLog | Select-Object -Last 10
    foreach ($line in $summary) {
        if ($line.Trim().Length -gt 0) {
            Add-Content -Path $logFile -Value "    $line" -Encoding UTF8
            if (-not $Silent) {
                Write-Host "    $line" -ForegroundColor Gray
            }
        }
    }
}

# 6. Evaluate Exit Codes (Robocopy bitmask: < 8 is success/no fatal error)
if ($exitCode -eq 0) {
    Write-SyncLog "Synchronization finished: Destination is up to date (0 changes)." "SUCCESS"
} elseif ($exitCode -ge 1 -and $exitCode -le 7) {
    Write-SyncLog "Synchronization finished successfully (changes copied, exit code $exitCode)." "SUCCESS"
} else {
    Write-SyncLog "Synchronization encountered errors (Robocopy exit code $exitCode). Check '$tempRoboLog'." "ERROR"
}

Write-SyncLog "=================================================="
exit $exitCode

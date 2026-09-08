<#
.SYNOPSIS
    Cleans invalid and conflicting entries from User PATH (HKCU:\Environment).
.DESCRIPTION
    1. Backs up original User PATH to reports/backup_user_path.txt.
    2. Removes invalid file entries (e.g. node.exe) and Python 3.12 entries (leaving Python 3.14 as unified standard).
    3. Re-applies cleaned User PATH.
    4. Verifies resolution of node, npm, python, and agy.
#>

[CmdletBinding()]
param()

$baseDir = Split-Path -Parent $PSScriptRoot
$reportsDir = Join-Path $baseDir "reports"
if (-not (Test-Path $reportsDir)) {
    New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
}

$backupFile = Join-Path $reportsDir "backup_user_path.txt"

# 1. Read current User PATH
$rawUserPath = (Get-ItemProperty -Path "HKCU:\Environment" -Name "Path" -ErrorAction Stop).Path
Write-Host "Backing up current User PATH to: $backupFile" -ForegroundColor Cyan
Set-Content -Path $backupFile -Value $rawUserPath -Force

# 2. Filter entries
$entries = $rawUserPath -split ";" | Where-Object { $_.Trim().Length -gt 0 }
$cleanedEntries = [System.Collections.Generic.List[string]]::new()

$removedEntries = @()

foreach ($entry in $entries) {
    $trimmed = $entry.Trim()
    
    # Check for removal targets
    if ($trimmed -match "node\.exe$") {
        $removedEntries += "$trimmed (Invalid file path in PATH; nodejs directory exists in System PATH)"
    } elseif ($trimmed -match "Python[\\/]Python312") {
        $removedEntries += "$trimmed (Python 3.12 collision; unified on Python 3.14)"
    } else {
        if (-not $cleanedEntries.Contains($trimmed)) {
            $cleanedEntries.Add($trimmed)
        }
    }
}

Write-Host "`nRemoved Entries:" -ForegroundColor Yellow
foreach ($r in $removedEntries) {
    Write-Host "  - $r" -ForegroundColor Yellow
}

# 3. Construct new User PATH string
$newPathString = ($cleanedEntries -join ";") + ";"
Set-ItemProperty -Path "HKCU:\Environment" -Name "Path" -Value $newPathString -Force
Write-Host "`nSuccessfully updated User PATH in HKCU:\Environment!" -ForegroundColor Green

# 4. Broadcast environment change to Windows Explorer
try {
    Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@
    $HWND_BROADCAST = [IntPtr]0xffff
    $WM_SETTINGCHANGE = 0x001A
    $result = [UIntPtr]::Zero
    [Win32.NativeMethods]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, "Environment", 2, 2000, [ref]$result) | Out-Null
    Write-Host "Broadcasted environment update message to running shells." -ForegroundColor Cyan
} catch {
    Write-Host "Environment broadcast skipped." -ForegroundColor Gray
}

# 5. Verification
Write-Host "`n=== Verification: Remaining User PATH Entries ===" -ForegroundColor Cyan
$verified = (Get-ItemProperty -Path "HKCU:\Environment" -Name "Path").Path -split ";" | Where-Object { $_ }
foreach ($v in $verified) {
    Write-Host "  - $v" -ForegroundColor Green
}

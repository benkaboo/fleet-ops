<#
.SYNOPSIS
    Removes %USERPROFILE%\.wslconfig to restore default WSL2 behavior.
#>

[CmdletBinding()]
param()

$targetConfig = Join-Path $env:USERPROFILE ".wslconfig"

if (Test-Path $targetConfig) {
    Remove-Item -Path $targetConfig -Force
    Write-Host "Removed $targetConfig. Restored default WSL allocation." -ForegroundColor Green
    wsl.exe --shutdown
} else {
    Write-Host "No .wslconfig found to remove." -ForegroundColor Yellow
}

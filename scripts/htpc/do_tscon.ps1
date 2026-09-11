param([string]$SessionId = "3")
$action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c tscon $SessionId /dest:console"
$principal = New-ScheduledTaskPrincipal -UserId 'NT AUTHORITY\SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName 'SwitchToConsole' -Action $action -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName 'SwitchToConsole'
Start-Sleep -Seconds 2
Unregister-ScheduledTask -TaskName 'SwitchToConsole' -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
Write-Host "Transferred session $SessionId to console as SYSTEM."

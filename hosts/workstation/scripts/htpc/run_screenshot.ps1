$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\Users\gamer\get_screenshot.ps1'
$principal = New-ScheduledTaskPrincipal -UserId 'gamer' -LogonType Interactive
$taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName 'TakeScreenshot_Temp' -Action $action -Principal $principal -Settings $taskSettings -Force | Out-Null
Start-ScheduledTask -TaskName 'TakeScreenshot_Temp'
Start-Sleep -Seconds 4
Unregister-ScheduledTask -TaskName 'TakeScreenshot_Temp' -Confirm:$false -ErrorAction SilentlyContinue

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$bb = Get-CimInstance Win32_BaseBoard
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$gpus = Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, VideoModeDescription, @{N='RAM_GB';E={[math]::Round($_.AdapterRAM/1GB, 2)}}
$audio = Get-CimInstance Win32_SoundDevice | Select-Object Name, Manufacturer, Status

# Storage
$disks = Get-PhysicalDisk | Select-Object DeviceId, FriendlyName, MediaType, BusType, @{N='SizeGB';E={[math]::Round($_.Size/1GB, 1)}}, HealthStatus, OperationalStatus
$vols = Get-PSDrive -PSProvider FileSystem | Select-Object Name, Root, @{N='TotalGB';E={[math]::Round(($_.Used + $_.Free)/1GB, 1)}}, @{N='UsedGB';E={[math]::Round($_.Used/1GB, 1)}}, @{N='FreeGB';E={[math]::Round($_.Free/1GB, 1)}}, @{N='PctFree';E={if (($_.Used + $_.Free) -gt 0) { [math]::Round(($_.Free/($_.Used + $_.Free))*100, 1) } else { 0 }}}
$smbMaps = Get-SmbMapping | Select-Object LocalPath, RemotePath, Status

# Network
$nets = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'vEthernet|Loopback' } | Select-Object InterfaceAlias, IPAddress, PrefixLength
$netAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object Name, InterfaceDescription, LinkSpeed, MacAddress

# Autostart
$runHKCU = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue
$runHKLM = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue

# Media & remote processes
$mediaProcs = Get-Process | Where-Object { $_.Name -match 'kodi|plex|jellyfin|vlc|steam|sunshine|moonlight|virtualdesktop|parsec|mpc' } | Select-Object Name, Id, @{N='RAM_MB';E={[math]::Round($_.WorkingSet64/1MB, 1)}}

# Services
$sshSvc = Get-Service sshd -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType
$rdpSvc = Get-Service TermService -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType

# Event Logs (Last 7 Days)
$startDate = (Get-Date).AddDays(-7)
$sysErrors = (Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=$startDate} -ErrorAction SilentlyContinue).Count
$appErrors = (Get-WinEvent -FilterHashtable @{LogName='Application'; Level=1,2; StartTime=$startDate} -ErrorAction SilentlyContinue).Count
$kp41 = (Get-WinEvent -FilterHashtable @{LogName='System'; Id=41; StartTime=$startDate} -ErrorAction SilentlyContinue).Count
$whea = (Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=$startDate} -ErrorAction SilentlyContinue).Count

[PSCustomObject]@{
    ComputerName = $cs.Name
    Domain = $cs.Domain
    Manufacturer = $cs.Manufacturer
    Model = $cs.Model
    Motherboard = "$($bb.Manufacturer) $($bb.Product)"
    OSCaption = $os.Caption
    OSVersion = $os.Version
    OSBuild = $os.BuildNumber
    OSArchitecture = $os.OSArchitecture
    LastBootUpTime = $os.LastBootUpTime.ToString("yyyy-MM-dd HH:mm:ss")
    UptimeDays = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalDays, 2)
    CPU = "$($cpu.Name) ($($cpu.NumberOfCores) Cores / $($cpu.NumberOfLogicalProcessors) Threads)"
    TotalRAM_GB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    FreeRAM_GB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    UsedRAM_GB = [math]::Round(($cs.TotalPhysicalMemory / 1GB) - ($os.FreePhysicalMemory / 1MB), 2)
    GPUs = $gpus
    Audio = $audio
    Disks = $disks
    Volumes = $vols
    SmbMappings = $smbMaps
    NetworkIPs = $nets
    NetworkAdapters = $netAdapters
    MediaProcesses = $mediaProcs
    RunHKCU = ($runHKCU.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | Select-Object Name, Value)
    RunHKLM = ($runHKLM.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | Select-Object Name, Value)
    SshService = $sshSvc
    RdpService = $rdpSvc
    EventSysErrors7d = $sysErrors
    EventAppErrors7d = $appErrors
    EventKernelPower41_7d = $kp41
    EventWHEA7d = $whea
} | ConvertTo-Json -Depth 5

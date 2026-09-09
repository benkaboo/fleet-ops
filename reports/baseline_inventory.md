# HTPC Host Baseline Inventory (RATH15-HTPC)

Generated: 2026-09-09 17:49:02
Target Node: RATH15-HTPC | OS: Microsoft Windows 11 Pro

## 1. System & Hardware Baseline
| Parameter | Value |
| :--- | :--- |
| **Host Name** | RATH15-HTPC |
| **OS Caption** | Microsoft Windows 11 Pro (64-bit) |
| **OS Version / Build** | 10.0.26200 (Build 26200) |
| **Last Boot Time** | 2026-09-09 10:49:01 (Uptime: 0.29 days) |
| **Motherboard** | Micro-Star International Co., Ltd. MAG B550 TOMAHAWK (MS-7C91) |
| **Processor** | AMD Ryzen 5 5600X 6-Core Processor              (6 Cores / 12 Threads) |
| **Total RAM** | 15.93 GB (Free: 4.32 GB, Used: 11.61 GB) |

## 2. Graphics & Audio Subsystem
### Video Controllers (GPUs)
| Device Name | Driver Version | Video Mode | Dedicated VRAM |
| :--- | :--- | :--- | :--- |
| Virtual Desktop Monitor | 15.39.56.845 | 3840 x 2160 x 4294967296 colors | 0 GB |
| NVIDIA GeForce RTX 3060 | 32.0.15.9621 | 3840 x 2160 x 4294967296 colors | 4 GB |

### Audio Devices
| Device Name | Manufacturer | Status |
| :--- | :--- | :--- |
| NVIDIA High Definition Audio | Microsoft | OK |
| Realtek High Definition Audio | Microsoft | OK |
| Steam Streaming Microphone | Valve Corporation Audio DDK | OK |
| Steam Streaming Speakers | Valve Corporation Audio DDK | OK |
| NVIDIA Virtual Audio Device (Wave Extensible) (WDM) | Microsoft | OK |
| Oculus Virtual Audio Device | Microsoft | OK |
| Virtual Desktop Audio | Microsoft | OK |

## 3. Storage Topology
### Physical Disks
| Disk | Friendly Name | Media Type | Bus Type | Size (GB) | Health | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 0 | CT1000MX500SSD1 | SSD | SATA | 931.5 | Healthy | OK |
| 1 | WDC WD40EFRX-68N32N0 | HDD | SATA | 3726 | Healthy | OK |

### Local Volumes & Mounted Drives
| Drive | Root | Total (GB) | Used (GB) | Free (GB) | % Free |
| :--- | :--- | :--- | :--- | :--- | :--- |
| C | C:\ | 930.6 | 465.4 | 465.2 | 50% |
| D | D:\ | 7.9 | 7.9 | 0 | 0% |
| F | F:\ | 1401.8 | 1309.8 | 92 | 6.6% |
| G | G:\ | 957 | 879.1 | 77.9 | 8.1% |
| H | H:\ | 1367.2 | 1283.1 | 84.1 | 6.2% |

### Network SMB Mappings
| Local | Remote Target | Status |
| :--- | :--- | :--- |
| M: | \\192.168.68.169\Media | 6 |
| N: | \\HPNAS01\files\Media | 6 |
| P: | \\HPNAS01\film | 6 |
| X: | \\HPNAS01\tvshows | 6 |

## 4. Network Configuration
| Interface | IP Address | Subnet Prefix |
| :--- | :--- | :--- |
| Ethernet 9 | 192.168.68.162 | /24 |
| Ethernet 8 | 169.254.240.7 | /16 |
| ZeroTier One [9bee8941b5f97bbb] | 192.168.192.2 | /24 |
| Bluetooth Network Connection 3 | 169.254.132.240 | /16 |
| NordLynx | 10.5.0.2 | /16 |
| OpenVPN Data Channel Offload for NordVPN | 169.254.232.65 | /16 |
| Local Area Connection 2 | 169.254.107.179 | /16 |
| Ethernet 3 | 169.254.250.243 | /16 |

## 5. Media Runtimes & Autostart Software
### Running Media / Remote Processes
| Process Name | PID | RAM (MB) |
| :--- | :--- | :--- |
| VirtualDesktop.Service | 5244 | 44.3 |

### Autostart Entries (HKCU - User Scope)
| Name | Command |
| :--- | :--- |
| OneDrive | `"C:\Users\benka_000\AppData\Local\Microsoft\OneDrive\OneDrive.exe" /background` |
| iCloudServices | `"C:\Program Files (x86)\Common Files\Apple\Internet Services\iCloudServices.exe"` |
| EpicGamesLauncher | `"F:\UE\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe" -silent -launchcontext=boot` |
| XDM | `"C:\Program Files (x86)\XDM\java-runtime\bin\javaw.exe" -Xmx1024m -jar "C:\Program Files (x86)\XDM\xdman.jar" -m` |
| NordVPN | `"C:\Program Files\NordVPN\NordVPN.exe"` |
| Discord | `C:\Users\benka_000\AppData\Local\Discord\Update.exe --processStart Discord.exe` |
| Steam | `"C:\Program Files (x86)\Steam\steam.exe" -silent` |
| MicrosoftEdgeAutoLaunch_594733247D47D557C7AB2F395A5A4B22 | `"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --no-startup-window --win-session-start` |

### Autostart Entries (HKLM - Machine Scope)
| Name | Command |
| :--- | :--- |
| SecurityHealth | `C:\WINDOWS\system32\SecurityHealthSystray.exe` |
| Greenshot | `C:\Program Files\Greenshot\Greenshot.exe` |
| XboxStat | `"C:\Program Files\Microsoft Xbox 360 Accessories\XboxStat.exe" silentrun` |
| EvtMgr6 | `C:\Program Files\Logitech\SetPointP\SetPoint.exe /launchGaming` |
| Acronis Scheduler2 Service | `"C:\Program Files (x86)\Common Files\Acronis\Schedule2\schedhlp.exe"` |

## 6. Remote Access Services
| Service | Status | Startup Type | Protocol / Port |
| :--- | :--- | :--- | :--- |
| OpenSSH (sshd) | 4 | 3 | Port 22 (TCP) |
| Remote Desktop (TermService) | 4 | 3 | Port 3389 (TCP) |

## 7. System Health & Error Telemetry (Last 7 Days)
| Metric | Count | Status |
| :--- | :--- | :--- |
| **System Event Errors** | 60 | Elevated |
| **Application Event Errors** | 25 | Normal |
| **Kernel-Power 41 (Unexpected Shutdowns)** | 0 | Clean |
| **WHEA Hardware Errors** | 0 | Clean (0) |



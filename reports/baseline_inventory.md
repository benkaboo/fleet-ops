# Workstation Host Baseline Inventory

Generated: 2026-09-08 22:48:11
Host Machine: LENOVO16_LP | User: benma

## 1. System & Hardware Baseline
| Parameter | Value |
| :--- | :--- |
| **OS Caption** | Microsoft Windows 11 Pro (64-bit) |
| **OS Version / Build** | 10.0.26200 (Build 26200) |
| **Last Boot Time** | 08/29/2026 17:43:19 |
| **Processor** | AMD Ryzen 5 7530U with Radeon Graphics          (6 Cores / 12 Threads) |
| **Total RAM** | 14.83 GB (Free: 2.76 GB) |
| **Manufacturer / Model** | LENOVO - 21JT001GAU |

## 2. Storage Topology
| Drive | Volume Name | File System | Total Size (GB) | Free Space (GB) | % Free |
| :--- | :--- | :--- | :--- | :--- | :--- |
| C: | Windows | NTFS | 474.72 | 204.61 | 43.1% |
| D: | 2_m2 | NTFS | 931.5 | 292.76 | 31.4% |
| G: | Google Drive | FAT32 | 474.72 | 194.38 | 40.9% |

## 3. Developer Toolchains & CLI Utilities
| Tool | Detected | Version / Path |
| :--- | :--- | :--- |
| Git | Yes | `git version 2.55.0.windows.3` |
| Python | Yes | `Python 3.14.6` |
| Python 3 | Yes | `Python 3.14.6` |
| Node.js | Yes | `v24.16.0` |
| npm | Yes | `C:\Program Files\nodejs\npm.ps1` |
| Cargo / Rust | No | Not in PATH |
| Go | No | Not in PATH |
| Docker CLI | No | Not in PATH |
| Winget | Yes | `v1.29.290` |
| Scoop | No | Not in PATH |
| Chocolatey | Yes | `2.7.3` |
| Antigravity CLI (agy) | Yes | `1.1.27` |

## 4. Virtualization & Subsystems
```text
  NAME      STATE           VERSION
* Ubuntu    Stopped         2
```

## 5. Active Network Adapters
| Interface Alias | IP Address | Description | Status |
| :--- | :--- | :--- | :--- |
| vEthernet (WSL (Hyper-V firewall)) | 192.168.0.1 | Hyper-V Virtual Ethernet Adapter | Up |
| Ethernet 2 | 169.254.108.58 | Realtek USB GbE Family Controller | Disconnected |
| Local Area Connection* 2 | 169.254.250.63 | N/A | Unknown |
| Bluetooth Network Connection | 169.254.42.216 | Bluetooth Device (Personal Area Network) | Disconnected |
| Local Area Connection* 1 | 169.254.27.125 | N/A | Unknown |
| Ethernet | 169.254.128.3 | Realtek PCIe GbE Family Controller | Disconnected |
| Wi-Fi | 192.168.68.163 | RZ616 Wi-Fi 6E 160MHz | Up |

## 6. Known Cache & Temporary Space Usage
| Cache Category | Path | Estimated Size (MB) | Status |
| :--- | :--- | :--- | :--- |
| User Temp (%TEMP%) | `C:\Users\benma\AppData\Local\Temp` | 169.47 MB | Present |
| npm Cache | `C:\Users\benma\AppData\Local\npm-cache` | 12 MB | Present |
| pip Cache | `C:\Users\benma\AppData\Local\pip\cache` | 0 MB | Present |
| Docker Desktop Data | `C:\Users\benma\AppData\Local\Docker` | 0 MB | Not Present |
| VS Code Cache | `C:\Users\benma\AppData\Roaming\Code\Cache` | 127.4 MB | Present |
| Antigravity CLI Logs | `C:\Users\benma\.gemini\antigravity-cli\logs` | 0 MB | Not Present |

## 7. Autostart Registry Entries
| Scope | Name | Command |
| :--- | :--- | :--- |
| HKCU (User) | OneDrive | `"C:\Users\benma\AppData\Local\Microsoft\OneDrive\OneDrive.exe" /background` |
| HKCU (User) | LenovoVantage | `C:\ProgramData\Lenovo\Vantage\Addins\LenovoCompanionAppAddin\1.0.0.58\LenovoVantage.exe` |
| HKCU (User) | LenovoVantageToolbar | `C:\ProgramData\Lenovo\Vantage\AddinData\LenovoBatteryGaugeAddin\x64\QSHelper.exe` |
| HKCU (User) | org.whispersystems.signal-desktop | `C:\Users\benma\AppData\Local\Programs\signal-desktop\Signal.exe --start-in-tray` |
| HKCU (User) | GoogleDriveFS | `"C:\Program Files\Google\Drive File Stream\130.0.2.0\GoogleDriveFS.exe" --startup_mode` |
| HKLM (System) | SecurityHealth | `C:\WINDOWS\system32\SecurityHealthSystray.exe` |
| HKLM (System) | AMMW | `"C:\Program Files\Lenovo\Ai Meeting Manager Service\Ammbkproc.exe" /startup_delay` |
| HKLM (System) | KeePass 2 PreLoad | `"C:\Program Files\KeePass Password Safe 2\KeePass.exe" --preload` |
| HKLM (System) | Logitech Download Assistant | `C:\Windows\system32\rundll32.exe C:\Windows\System32\LogiLDA.dll,LogiFetch` |
| HKLM (System) | Logi Download Assistant | `"C:\Program Files\LogiDownloadAssistant\bin\logi_download_assistant.exe" -system-restarted` |


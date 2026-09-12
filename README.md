# Federated Remote Gaming

High-performance, ultra-low latency federated game streaming pipeline pairing **Moonlight** (Client) on Workstation with **Sunshine** (Host) on HTPC, unified under **Playnite Fullscreen Mode**.

---

## Quick Start: Pairing & Playing

### 1. Initial Web UI Login (One-Time Setup)
1. Open your browser on the Workstation to **`https://192.168.68.162:47990`** (accept self-signed certificate).
2. Set your Sunshine administrator username and password.

### 2. Pair Moonlight with Sunshine
1. Launch **Moonlight** on your Workstation (available in Start Menu or run `& "$env:LOCALAPPDATA\Programs\Moonlight\Moonlight.exe"`).
2. Moonlight will automatically detect **`RATH15-HTPC`** on your local network (or click the "+" icon and enter `192.168.68.162`).
3. Click on the host tile; Moonlight will show a **4-digit PIN**.
4. In the Sunshine Web UI (`https://192.168.68.162:47990`), navigate to the **PIN** tab.
5. Enter the PIN and click **Send**. The lock icon on Moonlight will disappear.

### 3. Launch Games
Click **Playnite Fullscreen** inside Moonlight. You are now inside your unified console dashboard on your desk monitor, navigable with your Bluetooth Xbox controller across:
* **Steam**
* **Epic Games**
* **GOG Galaxy**
* **Amazon Games**
* **Amazon Luna**

---

## Architecture

For complete hardware, software, and network specifications, see [`ARCHITECTURE.md`](ARCHITECTURE.md).

For decision history and architectural change records, see [`CHANGELOG.md`](CHANGELOG.md).

# Federated Remote Gaming

High-performance, ultra-low latency federated game streaming pipeline pairing **Moonlight** (Client) on Workstation with **Sunshine** (Host) on HTPC, unified under **Playnite Fullscreen Mode**.

---

## Quick Start: Pairing & Playing

### 1. 1-Click Launch (Recommended)
Double-click the **Start Remote Gaming** shortcut on your Desktop (or run [`Start-RemoteGaming.ps1`](Start-RemoteGaming.ps1)).
This automatically:
- Probes `rath15-htpc.local` reachability over SSH.
- Detects if another user (e.g. Dylan on the TV) has active console control, and cleanly attaches your user session (`benka_000`) to the physical GPU console via `tscon`.
- Verifies Sunshine streaming service health and relaunches if necessary.
- Launches the **Moonlight** client ready to play.

### 2. Manual Connection
1. Launch **Moonlight** on your Workstation.
2. Select **`RATH15-HTPC`** (`rath15-htpc.local`).
3. Click **Playnite Fullscreen** (or **Desktop**). You are inside your unified console dashboard on your desk monitor, navigable with your Bluetooth Xbox controller across:
* **Steam** (`coppertrumpet2`)
* **Epic Games**
* **GOG Galaxy**
* **Amazon Games**
* **Amazon Luna**

### 3. Web UI Administration
Access the Sunshine Web UI at **`https://rath15-htpc.local:47990`** (accept self-signed certificate).

---

## Architecture

For complete hardware, software, and network specifications, see [`ARCHITECTURE.md`](ARCHITECTURE.md).

For decision history and architectural change records, see [`CHANGELOG.md`](CHANGELOG.md).

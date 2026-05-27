# WSL2 + Debian — Fresh Windows 10

Only manual step: creating the UNIX user when Debian first launches.

---

## Run

Open **PowerShell as Administrator**.

On a fresh machine with nothing downloaded:

```powershell
curl.exe -L -o C:\scripts.zip https://github.com/pannet1/scripts/archive/main.zip
Expand-Archive C:\scripts.zip C:\scripts -Force
cd C:\scripts\scripts-main\pwsh
.\1_setup_wsl.ps1
```

If you already have the files:

```powershell
.\1_setup_wsl.ps1
```

Reboot if prompted, then:

```powershell
.\2_install_debian.ps1
```

---

## What each script does

| Script | What it does |
|---|---|
| `1_setup_wsl.ps1` | Download scripts, enable WSL features, detect reboot |
| `2_install_debian.ps1` | Set WSL2 default, install Debian, install Nerd Font on Windows, configure Windows Terminal font |
| `3_pc_score.ps1` | (optional) Windows Experience Index benchmark |

---

## Other files

| File | Purpose |
|---|---|
| `reboot_to_bios.bat` | Reboot straight into UEFI/BIOS |
| `stream_android.bat` | scrcpy Android screen mirror (USB/WiFi) |

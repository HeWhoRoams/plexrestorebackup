# Plex Media Server Backup Script (PowerShell + 7-Zip)

This PowerShell script performs **automated backups of Plex Media Server configuration and registry data**. It supports both **application mode** and **service mode** installations, and can optionally compress the backup using 7-Zip if installed. The script is designed to run **headlessly**, making it ideal for overnight automated backups.

---

## Features

- Stops all Plex processes and the Plex service (if installed) to ensure clean backups.
- Copies Plex configuration to a timestamped backup folder, excluding cache and codecs.
- Optionally compresses the backup folder with 7-Zip (`.7z`) for smaller storage size.
- Retains a configurable number of backups, deleting older ones automatically.
- Restarts Plex after backup, attempting both service and application launches for reliability.
- Fully headless and suitable for scheduled tasks.

---

## Configuration

Edit the following variables at the top of the script:

```powershell
$BackupRoot = "D:\Plex_backup"        # Folder where backups will be stored
$PlexDataFolder = "$env:LOCALAPPDATA\Plex Media Server"
$PlexExePath = "$env:LOCALAPPDATA\Plex Media Server\Plex Media Server.exe"
$SevenZipPaths = @(
    "C:\Program Files\7-Zip\7z.exe",
    "C:\Program Files (x86)\7-Zip\7z.exe"
)
$RetentionDays = 30                    # Number of days to keep old backups
$Always_Restart_Plex = $true           # Restart Plex after backup (true/false)

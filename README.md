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

powershell
    $BackupRoot = "D:\Plex_backup"        # Folder where backups will be stored
    $PlexDataFolder = "$env:LOCALAPPDATA\Plex Media Server"
    $PlexExePath = "$env:LOCALAPPDATA\Plex Media Server\Plex Media Server.exe"
    $SevenZipPaths = @(
    "C:\Program Files\7-Zip\7z.exe",
    "C:\Program Files (x86)\7-Zip\7z.exe"
    )
    $RetentionDays = 30                    # Number of days to keep old backups
    $Always_Restart_Plex = $true           # Restart Plex after backup (true/false)

Ensure that $BackupRoot exists or the script will create it automatically.


##Usage

Open PowerShell as Administrator (required to stop/start services and kill processes).

Run the script manually:

    .\plex_backup.ps1

 Check the console or the log file (if configured) to verify backup completion.

##Setting Up a Scheduled Task (Windows)

To run this script automatically overnight:

 Open Task Scheduler.

Create a new task:

        Name: Plex Backup

        Run whether user is logged on or not

        Run with highest privileges

    Triggers: Set your preferred schedule (e.g., daily at 2:00 AM).

    Actions:

        Program/script: powershell.exe

        Add arguments:

        -NoProfile -ExecutionPolicy Bypass -File "C:\Path\To\plex_backup.ps1"

    Conditions: Optional – e.g., only run if on AC power.

    Settings: Allow task to be run on demand, stop if runs longer than a set time (optional).

##Best Practices

    7-Zip Installation: Install 7-Zip to enable compression. The script falls back to uncompressed backups if not found.

    Test First: Run the script manually before scheduling to ensure paths and permissions are correct.

    Retention Policy: Adjust $RetentionDays to match available storage.

    Headless Operation: $Always_Restart_Plex = $true ensures Plex is back online after backup.

    Monitoring: Consider redirecting output to a log file for automated monitoring:

    .\plex_backup.ps1 *> "D:\Plex_backup\PlexBackupLog.txt"

##License

This script is provided as-is for personal use. Modify and redistribute freely, but use at your own risk.

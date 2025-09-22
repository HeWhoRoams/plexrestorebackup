# ==================== Plex Backup Script (PowerShell + 7-Zip) ====================
# - Stops Plex cleanly (app or service) based on kill_plex config
# - Copies config to dated folder
# - Compresses with 7-Zip if available
# - Restarts Plex if Always_Restart_Plex = $true
# - Logs all output to a file named with the same timestamp as the backup
# ================================================================================

$kill_plex = $false

$BackupRoot = "D:\Plex_backup"
$Timestamp  = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$TempBackupFolder = Join-Path $BackupRoot "PlexTemp_$Timestamp"
$FinalArchive = Join-Path $BackupRoot "PlexBackup_$Timestamp.7z"
$LogFile      = Join-Path $BackupRoot "PlexBackup_$Timestamp.log"

$PlexDataFolder = "$env:LOCALAPPDATA\Plex Media Server"
$SevenZipPaths  = @(
    "C:\Program Files\7-Zip\7z.exe",
    "C:\Program Files (x86)\7-Zip\7z.exe"
)

$RetentionDays = 30
$Always_Restart_Plex = $true

# Redirect everything to log file
Start-Transcript -Path $LogFile -Append

Write-Host "=================== Starting Plex Backup ===================="

# ---------------- Stop Plex (Service + App) ----------------
if ($kill_plex) {
    Write-Host "Stopping Plex service (if installed)..."
    Stop-Service -Name "Plex Media Server" -Force -ErrorAction SilentlyContinue -Confirm:$false

    Write-Host "Stopping all Plex-related processes..."
    function Stop-PlexProcesses {
        $allPlex = Get-Process | Where-Object { $_.Name -like "Plex*" }
        if ($allPlex) {
            foreach ($proc in $allPlex) {
                Write-Host "Stopping process $($proc.Name) (PID=$($proc.Id))"
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue -Confirm:$false
            }
        } else {
            Write-Host "No Plex processes running."
        }
    }

    # First pass
    Stop-PlexProcesses
    Start-Sleep -Seconds 5

    # Loop until all Plex processes are gone (max 3 tries)
    $RetryLoop = 0
    do {
        $remaining = Get-Process | Where-Object { $_.Name -like "Plex*" }
        if ($remaining) {
            Write-Warning "Some Plex processes still running, retrying..."
            Stop-PlexProcesses
            Start-Sleep -Seconds 5
        }
        $RetryLoop++
    } until (-not (Get-Process | Where-Object { $_.Name -like "Plex*" }) -or $RetryLoop -ge 3)
} else {
    Write-Host "kill_plex is set to FALSE. Skipping Plex shutdown."
}

# ---------------- Copy data ----------------
Write-Host "Copying Plex data to temp folder: $TempBackupFolder"
robocopy $PlexDataFolder $TempBackupFolder /MIR /Z /R:3 /W:5 /XD "Cache" "Codecs"
if ($LASTEXITCODE -ge 8) {
    Write-Error "Robocopy failed with exit code $LASTEXITCODE"
    Stop-Transcript
    exit 1
}

# ---------------- Compress with 7-Zip ----------------
$SevenZipExe = $SevenZipPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($SevenZipExe) {
    Write-Host "Compressing backup with 7-Zip..."
    & $SevenZipExe a -t7z $FinalArchive "$TempBackupFolder*" -mx=9
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "7-Zip compression failed. Keeping uncompressed folder."
    } else {
        Write-Host "Compression complete. Removing temp folder..."
        Remove-Item $TempBackupFolder -Recurse -Force
    }
} else {
    Write-Warning "7-Zip not found. Keeping uncompressed backup folder."
}

# ---------------- Determine Plex executable ----------------
$PlexExePathsToTry = @(
    "C:\Program Files\Plex\Plex Media Server\Plex Media Server.exe",
    "$env:LOCALAPPDATA\Plex Media Server\Plex Media Server.exe"
)

$PlexExeToLaunch = $PlexExePathsToTry | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $PlexExeToLaunch) {
    Write-Error "Cannot find Plex Media Server executable in known locations."
}

# ---------------- Restart Plex ----------------
if ($Always_Restart_Plex) {
    Write-Host "Attempting to restart Plex (toggle enabled)..."
    $Retry = 0
    $Success = $false

    do {
        Write-Host "Starting Plex service..."
        Start-Service -Name "Plex Media Server" -ErrorAction SilentlyContinue

        if ($PlexExeToLaunch) {
            Write-Host "Starting Plex app..."
            Start-Process -FilePath $PlexExeToLaunch -ArgumentList "--minimized" -WorkingDirectory (Split-Path $PlexExeToLaunch)
        }

        # Small delay to let filesystem and Plex settle
        Start-Sleep -Seconds 10

        # Check if any Plex process is running
        $RunningProcesses = Get-Process | Where-Object { $_.Name -like "Plex*" }
        if ($RunningProcesses) {
            Write-Host "Plex successfully restarted:"
            $RunningProcesses | ForEach-Object { Write-Host "$($_.Name) (PID=$($_.Id))" }
            $Success = $true
            break
        } else {
            $Retry++
            Write-Warning "Restart attempt $Retry failed, retrying..."
        }
    } until ($Retry -ge 2)

    if (-not $Success) {
        Write-Error "CRITICAL: Plex failed to restart after backup!"
    }
} else {
    Write-Host "Always_Restart_Plex is set to FALSE. Skipping restart."
}

# ---------------- Retention cleanup ----------------
Write-Host "Pruning backups older than $RetentionDays days..."
$Cutoff = (Get-Date).AddDays(-$RetentionDays)
Get-ChildItem $BackupRoot -Include *.7z -File |
    Where-Object { $_.LastWriteTime -lt $Cutoff } |
    Remove-Item -Force

Write-Host "=================== Plex Backup Complete ===================="

Stop-Transcript

<#
    Plex Restore Script (PowerShell + 7-Zip)
    - Stops Plex cleanly (app or service)
    - Restores the latest backup from backup folder
    - Extracts 7-Zip archive if present
    - Restarts Plex
#>

# ---------------- Configuration ----------------
$BackupRoot = "D:\Plex_backup"
$PlexDataFolder = "$env:LOCALAPPDATA\Plex Media Server"
$PlexExePaths = @(
    "$env:LOCALAPPDATA\Plex Media Server\Plex Media Server.exe",
    "C:\Program Files\Plex\Plex Media Server\Plex Media Server.exe"
)
$Always_Restart_Plex = $true

Write-Host "=================== Starting Plex Restore ===================="

# ---------------- Stop Plex (Service + App) ----------------
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
Stop-PlexProcesses
Start-Sleep -Seconds 5

# ---------------- Locate Latest Backup ----------------
$latestBackup = Get-ChildItem $BackupRoot -Include *.7z, *-registry.xml -File | 
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $latestBackup) {
    Write-Error "No backups found in $BackupRoot"
    exit 1
}

Write-Host "Latest backup found: $($latestBackup.FullName)"

# ---------------- Restore Backup ----------------
$TempRestoreFolder = Join-Path $BackupRoot "PlexRestoreTemp"
if (Test-Path $TempRestoreFolder) { Remove-Item $TempRestoreFolder -Recurse -Force }

# If backup is a 7z archive, extract it
if ($latestBackup.Extension -eq ".7z") {
    $SevenZipExe = @(
        "C:\Program Files\7-Zip\7z.exe",
        "C:\Program Files (x86)\7-Zip\7z.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($SevenZipExe) {
        Write-Host "Extracting backup archive..."
        & $SevenZipExe x $latestBackup.FullName "-o$TempRestoreFolder" -y
    } else {
        Write-Error "7-Zip not found, cannot extract archive."
        exit 1
    }
} else {
    # If it's not an archive, assume a folder copy
    Write-Host "Copying backup folder contents..."
    Copy-Item -Path $latestBackup.FullName -Destination $TempRestoreFolder -Recurse -Force
}

# Copy restored data back to Plex data folder
Write-Host "Restoring Plex configuration to $PlexDataFolder..."
if (-not (Test-Path $PlexDataFolder)) { New-Item -ItemType Directory -Path $PlexDataFolder | Out-Null }
Copy-Item -Path "$TempRestoreFolder\*" -Destination $PlexDataFolder -Recurse -Force

# Cleanup temp folder
Remove-Item $TempRestoreFolder -Recurse -Force

# ---------------- Restore Plex Registry ----------------
$latestRegistry = Get-ChildItem $BackupRoot -Include *-registry.xml -File | 
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($latestRegistry) {
    Write-Host "Restoring Plex registry settings..."
    Import-Clixml -Path $latestRegistry.FullName | ForEach-Object {
        $keyPath = $_.PSPath
        foreach ($prop in $_.Property) {
            Set-ItemProperty -Path $keyPath -Name $prop -Value $_.Value -Force
        }
    }
} else {
    Write-Warning "No registry backup found."
}

# ---------------- Restart Plex ----------------
$PlexExeToLaunch = $PlexExePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($Always_Restart_Plex) {
    Write-Host "Attempting to restart Plex..."
    $Retry = 0
    $Success = $false

    do {
        Write-Host "Starting Plex service..."
        Start-Service -Name "Plex Media Server" -ErrorAction SilentlyContinue

        if ($PlexExeToLaunch) {
            Write-Host "Starting Plex app..."
            Start-Process -FilePath $PlexExeToLaunch -ArgumentList "--minimized" -WorkingDirectory (Split-Path $PlexExeToLaunch)
        }

        Start-Sleep -Seconds 5

        $RunningProcesses = Get-Process | Where-Object { $_.Name -like "Plex*" }
        if ($RunningProcesses) {
            Write-Host "Plex successfully restarted."
            $Success = $true
            break
        } else {
            $Retry++
            Write-Warning "Restart attempt $Retry failed, retrying..."
        }
    } until ($Retry -ge 2)

    if (-not $Success) {
        Write-Error "CRITICAL: Plex failed to restart after restore!"
    }
} else {
    Write-Host "Always_Restart_Plex is set to FALSE. Skipping restart."
}

Write-Host "=================== Plex Restore Complete ===================="

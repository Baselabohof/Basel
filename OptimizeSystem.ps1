# PowerShell script for full system optimization

function Safe-Remove {
    param(
        [string]$Path
    )
    try {
        if (Test-Path $Path) {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
        }
    } catch {
        Write-Host "Failed to remove $Path: $_"
    }
}

# Clean temporary folders
Safe-Remove "$env:TEMP\*"
Safe-Remove "$env:LOCALAPPDATA\Temp\*"
Safe-Remove "C:\\Windows\\SoftwareDistribution\\Download\\*"

# Clear Recycle Bin
try {
    Clear-RecycleBin -Force -ErrorAction Stop
} catch {
    Write-Host "Failed to clear Recycle Bin: $_"
}

# Restart Windows Update services
$services = @('wuauserv','bits','dosvc')
foreach ($svc in $services) {
    try { Stop-Service -Name $svc -Force -ErrorAction Stop } catch {}
}

Start-Sleep -Seconds 2

foreach ($svc in $services) {
    try { Start-Service -Name $svc -ErrorAction Stop } catch {}
}

# Set High Performance power plan and disable timeouts
try {
    powercfg /setactive SCHEME_MIN
    powercfg /change monitor-timeout-ac 0
    powercfg /change monitor-timeout-dc 0
    powercfg /change standby-timeout-ac 0
    powercfg /change standby-timeout-dc 0
} catch {
    Write-Host "Failed to set power options: $_"
}

# Show hidden files and file extensions
try {
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-ItemProperty -Path $adv -Name Hidden -Value 1 -ErrorAction Stop
    Set-ItemProperty -Path $adv -Name HideFileExt -Value 0 -ErrorAction Stop
} catch {
    Write-Host "Failed to set Explorer options: $_"
}

# Enable End Task on taskbar (Windows 11)
try {
    $devPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\DeveloperSettings'
    if (-not (Test-Path $devPath)) { New-Item -Path $devPath | Out-Null }
    Set-ItemProperty -Path $devPath -Name TaskbarEndTask -Value 1 -ErrorAction Stop
} catch {
    Write-Host "Failed to enable Taskbar End Task: $_"
}

# Install essential apps using winget
$apps = @(
    'Google.Chrome',
    '7zip.7zip',
    'VideoLAN.VLC',
    'Notepad++.Notepad++',
    'Adobe.Acrobat.Reader.64-bit'
)

foreach ($app in $apps) {
    try {
        winget install --id $app -e --silent --accept-package-agreements --accept-source-agreements
    } catch {
        Write-Host "Failed to install $app: $_"
    }
}

Write-Host "System optimization complete."

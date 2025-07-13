# Requires -RunAsAdministrator

<#
This script performs system optimization tasks for a freshly installed Windows laptop.
It cleans temporary files, clears the recycle bin, resets Windows Update cache,
sets power and File Explorer preferences, enables the taskbar "End Task" menu,
and installs a set of common applications via winget.
#>

function SafeRemove {
    param([string]$Path)
    if (Test-Path $Path) {
        try {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Warning "Failed to remove $Path: $_"
        }
    }
}

# Ensure script is run as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

Write-Host "Cleaning temporary files..."
SafeRemove "$env:TEMP\*"
SafeRemove "$env:LOCALAPPDATA\Temp\*"
SafeRemove "$env:SystemRoot\Temp\*"

Write-Host "Emptying Recycle Bin..."
try {
    Clear-RecycleBin -Force -ErrorAction Stop
} catch {
    Write-Warning "Failed to clear Recycle Bin: $_"
}

Write-Host "Resetting Windows Update cache..."
$updateServices = @('wuauserv', 'bits')
foreach ($svc in $updateServices) {
    try { Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue } catch { Write-Warning "Could not stop service $svc: $_" }
}
SafeRemove "$env:SystemRoot\SoftwareDistribution\Download\*"
foreach ($svc in $updateServices) {
    try { Start-Service -Name $svc -ErrorAction SilentlyContinue } catch { Write-Warning "Could not start service $svc: $_" }
}

Write-Host "Configuring power plan..."
try {
    powercfg -setactive SCHEME_MIN
    powercfg -change -monitor-timeout-ac 0
    powercfg -change -monitor-timeout-dc 0
    powercfg -change -standby-timeout-ac 0
    powercfg -change -standby-timeout-dc 0
} catch {
    Write-Warning "Failed to update power settings: $_"
}

Write-Host "Showing hidden files and extensions..."
try {
    $explorerKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-ItemProperty -Path $explorerKey -Name Hidden -Value 1 -ErrorAction Stop
    Set-ItemProperty -Path $explorerKey -Name HideFileExt -Value 0 -ErrorAction Stop
    Set-ItemProperty -Path $explorerKey -Name ShowSuperHidden -Value 1 -ErrorAction SilentlyContinue
} catch {
    Write-Warning "Failed to update Explorer settings: $_"
}

Write-Host "Enabling End Task option in taskbar..."
try {
    New-ItemProperty -Path $explorerKey -Name TaskbarEndTask -Value 1 -PropertyType DWord -Force -ErrorAction Stop
} catch {
    Write-Warning "Failed to enable End Task option: $_"
}

try {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
} catch {
    Write-Warning "Could not restart Explorer: $_"
}

Write-Host "Installing essential software via winget..."
$packages = @(
    'Google.Chrome',
    '7zip.7zip',
    'VideoLAN.VLC',
    'Notepad++.Notepad++',
    'Adobe.Acrobat.Reader.64-bit'
)
foreach ($pkg in $packages) {
    try {
        winget install --id $pkg --silent --accept-package-agreements --accept-source-agreements -e
    } catch {
        Write-Warning "Failed to install $pkg: $_"
    }
}

Write-Host "System optimization completed."

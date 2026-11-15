$ErrorActionPreference = 'Stop'

if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    throw 'WinGet was not found. Install App Installer, then run this script again.'
}

$AppIds = @(
    'Git.Git'
    'VideoLAN.VLC'
    'Microsoft.VisualStudioCode'
    '7zip.7zip'
    'Valve.Steam'
    'Netsdk.S3Browser' # CS Browser, formerly S3 Browser
    'Notepad++.Notepad++'
    'DominikReichl.KeePass'
)

foreach ($AppId in $AppIds) {
    & winget.exe list --id $AppId --exact --accept-source-agreements *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "$AppId is already installed; skipping." -ForegroundColor DarkGray
        continue
    }

    Write-Host "Installing $AppId..." -ForegroundColor Cyan
    & winget.exe install --id $AppId --exact --silent --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "WinGet failed to install $AppId (exit code $LASTEXITCODE)."
    }
}

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw 'WSL was not found. Enable or install WSL, then run this script again.'
}

Write-Host 'Installing WSL and Debian...' -ForegroundColor Cyan
& wsl.exe --install --distribution Debian --no-launch
if ($LASTEXITCODE -ne 0) {
    throw "WSL failed to install Debian (exit code $LASTEXITCODE)."
}

Write-Host 'Basic apps and WSL Debian installation completed. Launch Debian from the Start menu to finish its first-time setup.' -ForegroundColor Green

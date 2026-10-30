# List every available update, then update only the app IDs you specify.
# Run with IDs: .\winget.ps1 -AppIds 'Microsoft.PowerToys', 'VideoLAN.VLC'
# Or add your preferred IDs to the default list below, one quoted ID per line.
param (
    [string[]]$AppIds = @(
        'Balena.Etcher'                 # balenaEtcher
        'OpenAI.ChatGPT'                # ChatGPT
        'Netsdk.S3Browser'              # S3 Browser
        'DuckDuckGo.DesktopBrowser'     # DuckDuckGo
        'Electrum.Electrum'             # Electrum
        'Git.Git'                       # Git
        'GoTo.GoTo'                     # GoTo
        'DominikReichl.KeePass'          # KeePass Password Safe
        'Microsoft.Teams'               # Microsoft Teams
        'Microsoft.VCRedist.2015+.x64'   # Visual C++ Redistributable (64-bit)
        'Microsoft.VCRedist.2015+.x86'   # Visual C++ Redistributable (32-bit)
        'Notepad++.Notepad++'           # Notepad++
        'VideoLAN.VLC'                  # VLC media player
        'Microsoft.WindowsTerminal'    # Windows Terminal
        'Zoom.Zoom'                     # Zoom Workplace
    )
)

# Stop early if Windows Package Manager is not installed or available.
if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    throw 'WinGet was not found. Install App Installer, then run this script again.'
}

# With no app arguments, upgrade only lists available updates.
Write-Host "`nAll available updates:" -ForegroundColor Cyan
winget.exe upgrade

# Do not start updates if WinGet could not produce the list.
if ($LASTEXITCODE -ne 0) {
    Write-Warning "WinGet returned exit code $LASTEXITCODE. No updates were started."
    return
}

# An empty list lets you preview updates before choosing your apps.
if ($AppIds.Count -eq 0) {
    Write-Host "`nAdd app IDs to AppIds or pass -AppIds to update selected apps."
    return
}

# Exact ID matching prevents a similarly named app from being selected.
# WinGet displays any required agreement or installer prompts.
# Apps already up to date or not installed are left for WinGet to report.
foreach ($AppId in ($AppIds | Select-Object -Unique)) {
    if ([string]::IsNullOrWhiteSpace($AppId)) {
        continue
    }

    Write-Host "`nChecking for an update to $AppId..." -ForegroundColor Cyan
    winget.exe upgrade --id $AppId --exact

    # Keep checking the remaining apps if this app cannot be updated.
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "WinGet returned exit code $LASTEXITCODE for $AppId. See its message above."
    }
}

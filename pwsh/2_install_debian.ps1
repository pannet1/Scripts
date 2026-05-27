Write-Host "Setting WSL 2 as default version..." -ForegroundColor Cyan
wsl --set-default-version 2

Write-Host "Installing Debian..." -ForegroundColor Cyan
wsl --install -d Debian

# ── Install Nerd Font on Windows ──
$fontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip"
$fontName = "CaskaydiaCove Nerd Font Mono"
$tempZip = "$env:TEMP\CascadiaCode.zip"
$tempExtract = "$env:TEMP\CascadiaFonts"

if (!(Test-Path $tempExtract)) { New-Item -ItemType Directory -Path $tempExtract }

Write-Host "Downloading Cascadia Code Nerd Font..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $fontUrl -OutFile $tempZip

Write-Host "Extracting fonts..." -ForegroundColor Cyan
Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

$fontFolder = (New-Object -ComObject Shell.Application).Namespace(0x14)
$files = Get-ChildItem -Path $tempExtract -Filter "*.ttf"

Write-Host "Installing fonts to system..." -ForegroundColor Cyan
foreach ($file in $files) {
    if (!(Test-Path "C:\Windows\Fonts\$($file.Name)")) {
        $fontFolder.CopyHere($file.FullName, 0x10)
    } else {
        Write-Host "Already exists: $($file.Name)" -ForegroundColor Yellow
    }
}

Remove-Item $tempZip
Remove-Item $tempExtract -Recurse

# ── Set Windows Terminal font ──
$wtPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalCanary_8wekyb3d8bbwe\LocalState\settings.json"
)

$settingsPath = $null
foreach ($p in $wtPaths) {
    if (Test-Path $p) { $settingsPath = $p; break }
}

if ($settingsPath) {
    Write-Host "Setting Windows Terminal font to '$fontName'..." -ForegroundColor Cyan
    Copy-Item $settingsPath "$settingsPath.bak" -Force
    $json = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json

    if (-not ($json.PSObject.Properties.Name -contains 'profiles')) {
        $json | Add-Member -Type NoteProperty -Name 'profiles' -Value ([PSCustomObject]@{})
    }
    if (-not ($json.profiles.PSObject.Properties.Name -contains 'defaults')) {
        $json.profiles | Add-Member -Type NoteProperty -Name 'defaults' -Value ([PSCustomObject]@{})
    }
    if (-not ($json.profiles.defaults.PSObject.Properties.Name -contains 'font')) {
        $json.profiles.defaults | Add-Member -Type NoteProperty -Name 'font' -Value ([PSCustomObject]@{})
    }
    $json.profiles.defaults.font | Add-Member -Type NoteProperty -Name 'face' -Value $fontName -Force

    $json | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
    Write-Host "Windows Terminal font set to '$fontName'" -ForegroundColor Green
} else {
    Write-Host "Windows Terminal settings not found." -ForegroundColor Yellow
    Write-Host "After opening Windows Terminal, run this script again to set the font." -ForegroundColor Yellow
}

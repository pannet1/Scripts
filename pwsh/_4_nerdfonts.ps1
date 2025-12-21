# 1. Define the Download URL (Cascadia Code Nerd Font from official source)
$fontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip"
$tempZip = "$env:TEMP\CascadiaCode.zip"
$tempExtract = "$env:TEMP\CascadiaFonts"

# 2. Create temp directory
if (!(Test-Path $tempExtract)) { New-Item -ItemType Directory -Path $tempExtract }

Write-Host "Downloading Cascadia Code Nerd Font..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $fontUrl -OutFile $tempZip

Write-Host "Extracting fonts..." -ForegroundColor Cyan
Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

# 3. Install the Fonts
$fontFolder = (New-Object -ComObject Shell.Application).Namespace(0x14) # 0x14 = Windows Fonts folder
$files = Get-ChildItem -Path $tempExtract -Filter "*.ttf"

Write-Host "Installing fonts to system..." -ForegroundColor Cyan
foreach ($file in $files) {
    if (!(Test-Path "C:\Windows\Fonts\$($file.Name)")) {
        $fontFolder.CopyHere($file.FullName, 0x10)
        Write-Host "Installed: $($file.Name)" -ForegroundColor Green
    } else {
        Write-Host "Already exists: $($file.Name)" -ForegroundColor Yellow
    }
}

# 4. Cleanup
Remove-Item $tempZip
Remove-Item $tempExtract -Recurse
Write-Host "Setup Complete! Restart Windows Terminal to use 'CaskaydiaCove Nerd Font'." -ForegroundColor BrightWhite
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force

$Url = "https://github.com/pannet1/scripts/archive/main.zip"
$OutputZip = "C:\scripts.zip"
$ExtractDir = "C:\scripts"

Write-Host "Downloading scripts..." -ForegroundColor Cyan
curl.exe -L -o $OutputZip $Url
Expand-Archive -Path $OutputZip -DestinationPath $ExtractDir -Force
Remove-Item $OutputZip

Write-Host "Enabling Virtual Machine Platform and Windows Subsystem for Linux..." -ForegroundColor Cyan
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

$rebootPending = $false
if (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing" -Name "RebootPending" -ErrorAction SilentlyContinue) {
    $rebootPending = $true
}
if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
    $rebootPending = $true
}

if ($rebootPending) {
    Write-Host "Reboot required." -ForegroundColor Yellow
    Write-Host "After reboot, run:" -ForegroundColor Cyan
    Write-Host "  cd C:\scripts\scripts-main\pwsh && .\2_install_debian.ps1" -ForegroundColor White
} else {
    Write-Host "Ready. Run: .\2_install_debian.ps1" -ForegroundColor Green
}

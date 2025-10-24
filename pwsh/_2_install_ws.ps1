# SCRIPT START: Part 1 - Windows Feature Enabling

# 1. Enable the required Windows features: Virtual Machine Platform and WSL.
Write-Host "Enabling 'Virtual Machine Platform' and 'Windows Subsystem for Linux' features..."
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

# 2. Set WSL 2 as the default version for new distributions.
Write-Host "Setting WSL 2 as the default version for new distributions."
wsl --set-default-version 2

# 3. Check for pending reboot.
$rebootPending = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty PrimaryOwnerName
if ($rebootPending -ne $null) {
    Write-Host "Configuration complete. A system reboot is REQUIRED to finish the feature installation." -ForegroundColor Yellow
    Write-Host "After the reboot, proceed to Part 2: Manual Kernel Update & Installation." -ForegroundColor Yellow
    # Optionally, you can add a line to automatically reboot:
    # Read-Host "Press Enter to reboot now, or Ctrl+C to cancel."
    # Restart-Computer
} else {
    Write-Host "Features successfully enabled without requiring a reboot. Proceed immediately to Part 2." -ForegroundColor Green
}

# SCRIPT END: Part 1

# COMMAND START: Part 2B - Install Debian

# 1. Install Debian from the Microsoft Store (using the wsl command line tool)
Write-Host "Installing Debian... This may take a few minutes."
wsl --install -d Debian

winget install -e --id Microsoft.WindowsStore --source msstore

# COMMAND END: Part 2B

#!/bin/bash
set -euo pipefail

# Launch scrcpy (Android screen mirror) on Windows from WSL2

FIND_SCRCPY='$base = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
$pat = "Genymobile.scrcpy*"
$dir = Get-ChildItem -Path $base -Filter $pat -Name | Select-Object -First 1
if ($dir) {
    $exe = Get-ChildItem -Path "$base\$dir" -Recurse -Filter "scrcpy.exe" | Select-Object -First 1 -ExpandProperty FullName
    Write-Output $exe
}'

SCRCPY_PATH=$(powershell.exe -Command "$FIND_SCRCPY" 2>/dev/null | tr -d '\r')

if [ -z "$SCRCPY_PATH" ]; then
    echo "scrcpy not found. Install with:"
    echo "  powershell.exe -Command \"winget install Genymobile.scrcpy\""
    exit 1
fi

echo "Launching scrcpy..."
powershell.exe -Command "Start-Process -FilePath '$SCRCPY_PATH' -WindowStyle Normal" 2>/dev/null
echo "Done."

#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ok()    { echo "  $1 ✓"; }
fail()  { echo "  $1 ✗"; }
fix()   { echo "  → $1"; }
step()  { echo ""; echo "--- $1 ---"; }

check_cmd()   { command -v "$1" &>/dev/null; }
check_file()  { [ -f "$1" ]; }
check_dir()   { [ -d "$1" ]; }
check_line()  { grep -Fxq "$1" "$2" 2>/dev/null; }

PROJECT_DIR="$(realpath "${1:-.}")"

echo "=============================================="
echo "  Android/Kotlin Setup + Deploy (WSL2)"
echo "=============================================="
echo "  Project: $PROJECT_DIR"

ANDROID_SDK="$HOME/android-sdk"

# ── 1. Java & Dependencies ──
step "1/7: Java & Dependencies"
if check_cmd java; then
    ok "java available"
else
    fail "java"
    fix "installing default-jdk-headless"
    sudo apt install -y default-jdk-headless
    ok "java installed"
fi

# ── 2. Android cmdline-tools ──
step "2/7: Android cmdline-tools"
if [ -d "$ANDROID_SDK/cmdline-tools/latest/bin" ]; then
    ok "Android cmdline-tools"
else
    fail "Android cmdline-tools"
    mkdir -p "$ANDROID_SDK/cmdline-tools"
    cd /tmp
    fix "downloading Android command line tools"
    wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip
    unzip -q cmdline-tools.zip
    mv cmdline-tools "$ANDROID_SDK/cmdline-tools/latest"
    rm -f cmdline-tools.zip
    ok "Android cmdline-tools installed"
fi

# ── 3. Environment Variables ──
step "3/7: Environment Variables"
NEED_BASHRC=false
grep -q 'export ANDROID_HOME=' "$HOME/.bashrc" 2>/dev/null && ok "ANDROID_HOME" || { fail "ANDROID_HOME"; NEED_BASHRC=true; }
grep -q 'ANDROID_HOME/cmdline-tools/latest/bin' "$HOME/.bashrc" 2>/dev/null && ok "cmdline-tools PATH" || { fail "cmdline-tools PATH"; NEED_BASHRC=true; }
grep -q 'ANDROID_HOME/platform-tools' "$HOME/.bashrc" 2>/dev/null && ok "platform-tools PATH" || { fail "platform-tools PATH"; NEED_BASHRC=true; }

if $NEED_BASHRC; then
    fix "appending missing Android SDK exports to ~/.bashrc"
    cat >> "$HOME/.bashrc" << 'EOF'

# Android SDK
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
EOF
    ok "Android SDK exports added to .bashrc"
fi

# Source in current shell for script continuation
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"
export PATH="$PATH:$ANDROID_HOME/platform-tools"

# ── 4. SDK Packages ──
step "4/7: SDK Packages"
SDKMANAGER="$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager"

if [ -d "$ANDROID_SDK/licenses" ] && [ "$(ls -A "$ANDROID_SDK/licenses" 2>/dev/null)" ]; then
    ok "SDK licenses accepted"
else
    fail "SDK licenses"
    fix "accepting licenses"
    yes | "$SDKMANAGER" --licenses || true
    ok "SDK licenses accepted"
fi

MISSING=""
if [ -d "$ANDROID_SDK/platform-tools" ]; then
    ok "platform-tools"
else
    fail "platform-tools"
    MISSING="$MISSING platform-tools"
fi

if [ -d "$ANDROID_SDK/platforms/android-34" ]; then
    ok "platforms;android-34"
else
    fail "platforms;android-34"
    MISSING="$MISSING platforms;android-34"
fi

if [ -d "$ANDROID_SDK/build-tools/34.0.0" ]; then
    ok "build-tools;34.0.0"
else
    fail "build-tools;34.0.0"
    MISSING="$MISSING build-tools;34.0.0"
fi

if [ -n "$MISSING" ]; then
    fix "installing missing:$MISSING"
    if "$SDKMANAGER" $MISSING; then
        ok "SDK packages installed"
    else
        fail "SDK package installation (check internet)"
    fi
fi

# ── 5. local.properties ──
step "5/7: Project local.properties"
if [ -f "$PROJECT_DIR/local.properties" ]; then
    ok "local.properties exists"
else
    fail "local.properties"
    echo "sdk.dir=$ANDROID_SDK" > "$PROJECT_DIR/local.properties"
    ok "local.properties created"
fi

# ── 6. ADB Bridge (WSL2 → Windows) ──
step "6/7: ADB Bridge (WSL2 → Windows)"

add_adb_firewall_rule() {
    local wsl_subnet="$1"
    if check_cmd powershell.exe; then
        fix "adding Windows Firewall rule for ADB (port 5037, subnet $wsl_subnet)"
        powershell.exe -Command "
            \$rule = Get-NetFirewallRule -DisplayName 'WSL ADB Bridge' -ErrorAction SilentlyContinue
            if (-not \$rule) {
                New-NetFirewallRule -DisplayName 'WSL ADB Bridge' -Direction Inbound -Protocol TCP -LocalPort 5037 -RemoteAddress '$wsl_subnet' -Action Allow | Out-Null
                Write-Output 'added'
            } else {
                Write-Output 'exists'
            }
        " 2>/dev/null | grep -q "added" && ok "Firewall rule added" || ok "Firewall rule already exists"
    fi
}

if grep -qi microsoft /proc/version 2>/dev/null; then
    if grep -q "ADB_SERVER_SOCKET" "$HOME/.bashrc" 2>/dev/null; then
        ok "ADB WSL2 socket configured"
    else
        fail "ADB WSL2 socket"
        fix "adding ADB_SERVER_SOCKET to ~/.bashrc"
        cat >> "$HOME/.bashrc" << 'EOF'

# ADB bridge (WSL2 → Windows)
export ADB_SERVER_SOCKET=tcp:$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):5037
EOF
        ok "ADB_SERVER_SOCKET added to .bashrc"
    fi

    if check_cmd powershell.exe; then
        FIND_ADB='$base = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"; $pat = "Google.PlatformTools*"; $dir = Get-ChildItem -Path $base -Filter $pat -Name | Select-Object -First 1; if ($dir) { Write-Output "$base\$dir\platform-tools\adb.exe" } else { Write-Output "" }'
        ADB_WIN_PATH=$(powershell.exe -Command "$FIND_ADB" 2>/dev/null | tr -d '\r')
        if [ -n "$ADB_WIN_PATH" ] && powershell.exe -Command "Test-Path '$ADB_WIN_PATH'" 2>/dev/null | grep -q True; then
            ok "ADB available on Windows"
        else
            fail "ADB not found on Windows"
            fix "installing via winget"
            if powershell.exe -Command "winget install Google.PlatformTools --accept-package-agreements --accept-source-agreements"; then
                ok "ADB installed via winget"
                ADB_WIN_PATH=$(powershell.exe -Command "$FIND_ADB" 2>/dev/null | tr -d '\r')
            else
                fail "winget install failed"
                fix "Install manually: winget install Google.PlatformTools"
            fi
        fi

        if [ -n "$ADB_WIN_PATH" ]; then
            fix "starting ADB server on Windows"
            powershell.exe -Command "& '$ADB_WIN_PATH' kill-server" 2>/dev/null || true
            sleep 1
            if powershell.exe -Command "\$p = Start-Process -FilePath '$ADB_WIN_PATH' -ArgumentList '-a','-P','5037','nodaemon','server' -WindowStyle Hidden -PassThru; Write-Output \$p.Id" 2>/dev/null; then
                sleep 2
                WSL_HOST=$(grep nameserver /etc/resolv.conf | awk '{print $2}')
                WSL_SUBNET=$(ip route show default | awk '{print $3}' | sed 's/\.[0-9]*$/\.0\/20/')
                if timeout 3 bash -c "echo > /dev/tcp/$WSL_HOST/5037" 2>/dev/null; then
                    ok "ADB server started on Windows (port 5037)"
                else
                    fail "ADB server not reachable via TCP (Windows firewall may be blocking)"
                    add_adb_firewall_rule "$WSL_SUBNET"
                    sleep 1
                    if timeout 3 bash -c "echo > /dev/tcp/$WSL_HOST/5037" 2>/dev/null; then
                        ok "ADB server reachable after firewall rule"
                    else
                        fail "ADB server still not reachable — will use PowerShell for ADB commands"
                    fi
                fi
            else
                fail "Could not start ADB server on Windows"
            fi
        fi
    else
        fail "powershell.exe not available (not in WSL?)"
    fi
fi

# ── 7. Build & Deploy ──
step "7/7: Build & Deploy"

cd "$PROJECT_DIR"

    fix "building APK..."
    if ./gradlew assembleDebug; then
        ok "Build successful"
    else
        fail "Build failed"
        exit 1
    fi

    APK="$PROJECT_DIR/app/build/outputs/apk/debug/app-debug.apk"
    if [ ! -f "$APK" ]; then
        fail "APK not found at $APK"
        exit 1
    fi

    if [ -n "$ADB_WIN_PATH" ]; then
        fix "checking for connected device..."
        DEVICES=$(powershell.exe -Command "& '$ADB_WIN_PATH' devices" 2>/dev/null | grep -v 'List of devices attached' | grep -v '^\s*$' | wc -l)
        if [ "$DEVICES" -gt 0 ]; then
            APK_WIN="\\\\wsl.localhost\\Debian${APK//\//\\}"
            fix "installing APK..."
            if powershell.exe -Command "& '$ADB_WIN_PATH' install '$APK_WIN'" 2>&1 | grep -q "Success"; then
                ok "APK installed"
                powershell.exe -Command "& '$ADB_WIN_PATH' shell am start -n com.example.hellokotlin/.MainActivity" 2>/dev/null
                ok "App launched"
            else
                fail "Install failed — check device authorization"
                fix "On your phone, allow USB debugging authorization"
            fi
        else
            fail "No device connected"
            fix "Connect your phone via USB, enable USB debugging, then run:"
            fix "  $ADB_WIN_PATH install $APK_WIN"
        fi
    else
        fail "ADB not available on Windows"
        fix "Install ADB manually: winget install Google.PlatformTools"
        fix "Then run: adb install $APK"
    fi

echo ""
echo "=============================================="
echo "  Complete!"
echo "=============================================="
echo ""
echo "  source ~/.bashrc"

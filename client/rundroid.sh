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

usage() {
  echo "Usage: $(basename "$0") [project-directory]"
  echo ""
  echo "If no directory is given, uses the current directory."
  echo "If the directory has no Android project, scaffolds a starter template."
  exit 1
}

PROJECT_DIR="$(realpath "${1:-.}")"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
PACKAGE_NAME="com.${PROJECT_NAME,,}"

MANIFEST="$PROJECT_DIR/app/src/main/AndroidManifest.xml"

scaffold_project() {
  step "0/7: Project Template"
  fail "no Android project found"
  fix "scaffolding starter at $PROJECT_DIR"

  local src_main="$PROJECT_DIR/app/src/main"
  local java_dir="$src_main/java/${PACKAGE_NAME//.//}"
  local res_dir="$src_main/res/values"
  local layout_dir="$src_main/res/layout"

  mkdir -p "$java_dir" "$res_dir" "$layout_dir" "$PROJECT_DIR/gradle/wrapper"

  cat > "$PROJECT_DIR/settings.gradle.kts" << 'EOF'
pluginManagement {
  repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolution {
  repositories { google(); mavenCentral() }
}
rootProject.name = "__PROJECT__"
include(":app")
EOF
  sed -i "s/__PROJECT__/$PROJECT_NAME/" "$PROJECT_DIR/settings.gradle.kts"

  cat > "$PROJECT_DIR/build.gradle.kts" << 'EOF'
plugins {
  id("com.android.application") version "8.2.0" apply false
  id("org.jetbrains.kotlin.android") version "1.9.22" apply false
}
EOF

  cat > "$PROJECT_DIR/app/build.gradle.kts" << 'EOF'
plugins {
  id("com.android.application")
  id("org.jetbrains.kotlin.android")
}
android {
  namespace = "__PACKAGE__"
  compileSdk = 34
  defaultConfig {
    applicationId = "__PACKAGE__"
    minSdk = 24
    targetSdk = 34
    versionCode = 1
    versionName = "1.0"
  }
  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }
  kotlinOptions { jvmTarget = "17" }
}
dependencies {
  implementation("androidx.core:core-ktx:1.12.0")
  implementation("androidx.appcompat:appcompat:1.6.1")
}
EOF
  sed -i "s/__PACKAGE__/$PACKAGE_NAME/g" "$PROJECT_DIR/app/build.gradle.kts"

  cat > "$PROJECT_DIR/gradle.properties" << 'EOF'
org.gradle.jvmargs=-Xmx2g
android.useAndroidX=true
EOF

  cat > "$PROJECT_DIR/gradle/wrapper/gradle-wrapper.properties" << 'EOF'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.5-bin.zip
networkTimeout=10000
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOF

  cat > "$src_main/AndroidManifest.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application android:label="@string/app_name">
    <activity android:name=".MainActivity" android:exported="true">
      <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
      </intent-filter>
    </activity>
  </application>
</manifest>
EOF

  cat > "$java_dir/MainActivity.kt" << 'EOF'
package __PACKAGE__

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_main)
  }
}
EOF
  sed -i "s/__PACKAGE__/$PACKAGE_NAME/" "$java_dir/MainActivity.kt"

  cat > "$res_dir/strings.xml" << 'EOF'
<resources>
  <string name="app_name">__PROJECT__</string>
</resources>
EOF
  sed -i "s/__PROJECT__/$PROJECT_NAME/" "$res_dir/strings.xml"

  cat > "$res_dir/themes.xml" << 'EOF'
<resources>
  <style name="Theme.__PROJECT__" parent="Theme.AppCompat.Light.DarkActionBar" />
</resources>
EOF
  sed -i "s/__PROJECT__/$PROJECT_NAME/" "$res_dir/themes.xml"

  cat > "$src_main/res/layout/activity_main.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
  android:layout_width="match_parent"
  android:layout_height="match_parent">
  <TextView
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:layout_gravity="center"
    android:text="Hello World!" />
</FrameLayout>
EOF

  fix "downloading Gradle wrapper..."
  cd "$PROJECT_DIR"
  if check_cmd gradle; then
    gradle wrapper --gradle-version 8.5 2>/dev/null || true
  fi
  if [ ! -f gradlew ]; then
    curl -sL "https://services.gradle.org/distributions/gradle-8.5-bin.zip" -o /tmp/gradle-wrapper.zip
    cat > gradlew << 'SCRIPT'
#!/bin/sh
# Gradle wrapper placeholder — install Gradle manually or run: gradle wrapper
SCRIPT
    chmod +x gradlew
  fi

  ok "starter template created at $PROJECT_DIR"
}

if [ ! -f "$MANIFEST" ]; then
  if [ "$#" -eq 0 ]; then
    echo "No Android project found at current directory."
    echo "Tip: pass a project path as argument, e.g.: $(basename "$0") /path/to/android/project"
    echo ""
  fi
  scaffold_project
fi

APP_ID=$(grep 'applicationId\s*=' "$PROJECT_DIR/app/build.gradle.kts" 2>/dev/null | head -1 | sed 's/.*"\(.*\)".*/\1/')
ACTIVITY_FULL=$(grep 'android:name=' "$MANIFEST" 2>/dev/null | head -1 | sed 's/.*"\(.*\)".*/\1/')

echo "=============================================="
echo "  Android/Kotlin Setup + Deploy (WSL2)"
echo "=============================================="
echo "  Project: $PROJECT_DIR"
echo "  App ID: $APP_ID | Activity: $ACTIVITY_FULL"

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

if [ ! -f gradlew ]; then
  fix "generating Gradle wrapper..."
  if check_cmd gradle; then
    gradle wrapper --gradle-version 8.5
  else
    fix "installing Gradle..."
    cd /tmp
    curl -sL "https://services.gradle.org/distributions/gradle-8.5-bin.zip" -o gradle.zip
    sudo unzip -q gradle.zip -d /opt
    sudo ln -sf /opt/gradle-8.5/bin/gradle /usr/local/bin/gradle
    rm gradle.zip
    cd "$PROJECT_DIR"
    gradle wrapper --gradle-version 8.5
  fi
  ok "Gradle wrapper ready"
fi

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
                powershell.exe -Command "& '$ADB_WIN_PATH' shell am start -n $APP_ID/$ACTIVITY_FULL" 2>/dev/null
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

#!/usr/bin/env bash
# Build an installable Android APK of Celestial Q Siege on a plain Linux x86_64 box
# (e.g. a Cursor cloud agent VM) with no root and nothing preinstalled except
# bash, curl/wget, unzip, tar.
#
# Downloads (once, cached in $TOOLS_DIR):
#   - Godot 4.7.2 headless editor + Android export templates
#   - Temurin JDK 17
#   - Android cmdline-tools, platform-tools, build-tools 35.0.0, platform 35
#   - a debug keystore
# Then exports the "Android" preset.
#
# Usage:
#   scripts/build-apk.sh            # debug-signed APK -> build/CelestialQSiege-debug.apk
#   scripts/build-apk.sh release    # release APK; needs GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD
#
# Env overrides: TOOLS_DIR (default ~/.cache/cqs-godot-tools), GODOT_VERSION (default 4.7.2).
set -euo pipefail

MODE="${1:-debug}"
GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
GODOT_RELEASE="${GODOT_VERSION}-stable"
TOOLS_DIR="${TOOLS_DIR:-$HOME/.cache/cqs-godot-tools}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APK_NAME="CelestialQSiege"
PRESET="Android"

GODOT_BIN="$TOOLS_DIR/Godot_v${GODOT_RELEASE}_linux.x86_64"
JDK_DIR="$TOOLS_DIR/jdk17"
SDK_DIR="$TOOLS_DIR/android-sdk"
KEYSTORE="$TOOLS_DIR/debug.keystore"
TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
GODOT_MINOR="$(echo "$GODOT_VERSION" | cut -d. -f1-2)"
EDITOR_SETTINGS="$HOME/.config/godot/editor_settings-${GODOT_MINOR}.tres"

mkdir -p "$TOOLS_DIR"
dl() { curl -fL --retry 3 -sS -o "$2" "$1"; }

# 1. Godot editor (headless-capable standard build)
if [ ! -x "$GODOT_BIN" ]; then
  echo ">> Downloading Godot $GODOT_RELEASE"
  dl "https://github.com/godotengine/godot-builds/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_linux.x86_64.zip" "$TOOLS_DIR/godot.zip"
  unzip -oq "$TOOLS_DIR/godot.zip" -d "$TOOLS_DIR" && rm -f "$TOOLS_DIR/godot.zip"
  chmod +x "$GODOT_BIN"
fi

# 2. Android export templates only (the full .tpz is ~1.3 GB; we keep just android_*)
if [ ! -f "$TEMPLATES_DIR/android_debug.apk" ]; then
  echo ">> Downloading Godot $GODOT_RELEASE export templates (large, one-time)"
  dl "https://github.com/godotengine/godot-builds/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_export_templates.tpz" "$TOOLS_DIR/templates.tpz"
  mkdir -p "$TEMPLATES_DIR" "$TOOLS_DIR/tpl"
  unzip -oq "$TOOLS_DIR/templates.tpz" 'templates/android*' 'templates/version.txt' -d "$TOOLS_DIR/tpl"
  mv "$TOOLS_DIR"/tpl/templates/* "$TEMPLATES_DIR/"
  rm -rf "$TOOLS_DIR/tpl" "$TOOLS_DIR/templates.tpz"
fi

# 3. JDK 17
if [ ! -x "$JDK_DIR/bin/java" ]; then
  echo ">> Downloading Temurin JDK 17"
  dl "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse" "$TOOLS_DIR/jdk.tgz"
  mkdir -p "$JDK_DIR" && tar xzf "$TOOLS_DIR/jdk.tgz" -C "$JDK_DIR" --strip-components=1 && rm -f "$TOOLS_DIR/jdk.tgz"
fi
export JAVA_HOME="$JDK_DIR" PATH="$JDK_DIR/bin:$PATH"

# 4. Android SDK (cmdline-tools + build-tools for apksigner/zipalign)
if [ ! -d "$SDK_DIR/build-tools/35.0.0" ]; then
  echo ">> Installing Android SDK packages"
  if [ ! -x "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" ]; then
    dl "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" "$TOOLS_DIR/clt.zip"
    mkdir -p "$SDK_DIR/cmdline-tools"
    unzip -oq "$TOOLS_DIR/clt.zip" -d "$SDK_DIR/cmdline-tools" && rm -f "$TOOLS_DIR/clt.zip"
    rm -rf "$SDK_DIR/cmdline-tools/latest" && mv "$SDK_DIR/cmdline-tools/cmdline-tools" "$SDK_DIR/cmdline-tools/latest"
  fi
  yes | "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK_DIR" --licenses >/dev/null || true
  "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK_DIR" "platform-tools" "build-tools;35.0.0" "platforms;android-35" >/dev/null
fi
export ANDROID_HOME="$SDK_DIR"

# 5. Debug keystore
if [ ! -f "$KEYSTORE" ]; then
  keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore "$KEYSTORE" \
    -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 >/dev/null 2>&1
fi

# 6. Godot editor settings pointing at the tools above (per-user file; outside the repo)
mkdir -p "$(dirname "$EDITOR_SETTINGS")"
if [ ! -f "$EDITOR_SETTINGS" ] || ! grep -q "$SDK_DIR" "$EDITOR_SETTINGS"; then
  cat > "$EDITOR_SETTINGS" <<TRES
[gd_resource type="EditorSettings" format=3]
[resource]
export/android/java_sdk_path = "$JDK_DIR"
export/android/android_sdk_path = "$SDK_DIR"
export/android/debug_keystore = "$KEYSTORE"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
export/android/shutdown_adb_on_exit = true
TRES
fi

# 7. Import + export
cd "$PROJECT_DIR"
mkdir -p build
echo ">> Importing project"
"$GODOT_BIN" --headless --import
if [ "$MODE" = "release" ]; then
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?set GODOT_ANDROID_KEYSTORE_RELEASE_PATH (and _USER, _PASSWORD) for release builds}"
  OUT="build/${APK_NAME}-release.apk"
  echo ">> Exporting release APK -> $OUT"
  "$GODOT_BIN" --headless --export-release "$PRESET" "$OUT"
else
  OUT="build/${APK_NAME}-debug.apk"
  echo ">> Exporting debug APK -> $OUT"
  "$GODOT_BIN" --headless --export-debug "$PRESET" "$OUT"
fi
test -s "$OUT" || { echo "ERROR: export produced no APK at $OUT" >&2; exit 1; }
"$SDK_DIR/build-tools/35.0.0/apksigner" verify "$OUT" && echo ">> OK: $(du -h "$OUT" | cut -f1) $PROJECT_DIR/$OUT"

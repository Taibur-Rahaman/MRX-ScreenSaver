#!/usr/bin/env bash
# Build a native Objective-C Flip Clock .saver (no Swift / no WebKit).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SAVER_BUNDLE="$ROOT/macos/MRXScreenSaver.saver"
MACOS_DIR="$SAVER_BUNDLE/Contents/MacOS"
SRC="$ROOT/macos/MRXScreenSaverView.m"
BINARY="$MACOS_DIR/MRXScreenSaver"

echo "🍎 Compiling Objective-C Flip Clock ScreenSaver (universal arm64+x86_64)..."
SDK="$(xcrun --sdk macosx --show-sdk-path)"
MIN_VER="13.0"

mkdir -p "$MACOS_DIR" "$SAVER_BUNDLE/Contents/Resources"

sign_saver() {
  local bundle="$1"
  codesign --force --sign - --timestamp=none "$bundle/Contents/MacOS/MRXScreenSaver" 2>/dev/null || true
  codesign --force --deep --sign - --timestamp=none "$bundle" 2>/dev/null || true
}

# Universal binary so Intel + Apple Silicon Macs both work (CI is arm64-only by default).
xcrun clang \
  -fobjc-arc \
  -bundle \
  -o "$BINARY" \
  -isysroot "$SDK" \
  -F "$SDK/System/Library/Frameworks" \
  -framework ScreenSaver \
  -framework Cocoa \
  -framework QuartzCore \
  -framework AppKit \
  -framework Foundation \
  -arch arm64 -arch x86_64 \
  -mmacosx-version-min="$MIN_VER" \
  "$SRC"

chmod +x "$BINARY"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 0.1.20" "$SAVER_BUNDLE/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 20" "$SAVER_BUNDLE/Contents/Info.plist" 2>/dev/null || true

sign_saver "$SAVER_BUNDLE"

echo "✅ Built: $BINARY ($(file -b "$BINARY"))"

USER_SAVER="$HOME/Library/Screen Savers/MRXScreenSaver.saver"
mkdir -p "$HOME/Library/Screen Savers"
rm -rf "$USER_SAVER"
cp -R "$SAVER_BUNDLE" "$USER_SAVER"
xattr -cr "$USER_SAVER" 2>/dev/null || true
sign_saver "$USER_SAVER"

defaults -currentHost write com.apple.screensaver showClock -bool false
defaults -currentHost write com.apple.screensaver moduleDict -dict \
  moduleName "MRX ScreenSaver" \
  path "$USER_SAVER" \
  type -int 0

killall legacyScreenSaver 2>/dev/null || true
killall "Screen Saver" 2>/dev/null || true
killall ScreenSaverEngine 2>/dev/null || true

echo ""
echo "Installed → $USER_SAVER"
echo ""
echo "If you downloaded from GitHub/Chrome, use scripts/macos/Install-MRX-ScreenSaver.command"
echo "instead of double-clicking the .saver (avoids 'damaged' + black screen)."
echo ""
echo "If black screen persists:"
echo "  sudo rm -rf \"/Library/Screen Savers/MRXScreenSaver.saver\""
echo "Then: System Settings → Screen Saver → MRX ScreenSaver → Preview"

#!/usr/bin/env bash
# Build a native Objective-C Flip Clock .saver (no Swift / no WebKit).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SAVER_BUNDLE="$ROOT/macos/MRXScreenSaver.saver"
MACOS_DIR="$SAVER_BUNDLE/Contents/MacOS"
SRC="$ROOT/macos/MRXScreenSaverView.m"
BINARY="$MACOS_DIR/MRXScreenSaver"

echo "🍎 Compiling Objective-C Flip Clock ScreenSaver..."
SDK="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macosx13.0"

mkdir -p "$MACOS_DIR" "$SAVER_BUNDLE/Contents/Resources"

# Mach-O bundle for ScreenSaver.framework — pure ObjC, no Swift runtime.
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
  -target "$TARGET" \
  "$SRC"

chmod +x "$BINARY"

codesign --force --deep -s - "$SAVER_BUNDLE" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 0.1.9" "$SAVER_BUNDLE/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 9" "$SAVER_BUNDLE/Contents/Info.plist" 2>/dev/null || true

echo "✅ Built: $BINARY ($(file -b "$BINARY"))"

USER_SAVER="$HOME/Library/Screen Savers/MRXScreenSaver.saver"
mkdir -p "$HOME/Library/Screen Savers"
rm -rf "$USER_SAVER"
cp -R "$SAVER_BUNDLE" "$USER_SAVER"
xattr -dr com.apple.quarantine "$USER_SAVER" 2>/dev/null || true
codesign --force --deep -s - "$USER_SAVER" 2>/dev/null || true

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
echo "REQUIRED if black screen persists:"
echo "  sudo rm -rf \"/Library/Screen Savers/MRXScreenSaver.saver\""
echo "Then: System Settings → Screen Saver → MRX ScreenSaver → Preview"

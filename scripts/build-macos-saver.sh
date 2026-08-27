#!/usr/bin/env bash
# Build a native (no WebKit) macOS .saver flip-clock bundle.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SAVER_BUNDLE="$ROOT/macos/MRXScreenSaver.saver"
MACOS_DIR="$SAVER_BUNDLE/Contents/MacOS"
SWIFT_SRC="$ROOT/macos/ScreenSaverView.swift"
BINARY="$MACOS_DIR/MRXScreenSaver"
WWW_DIR="$SAVER_BUNDLE/Contents/Resources/www"

echo "🍎 Compiling native Flip Clock ScreenSaver (no WebKit)..."
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "❌ swiftc not found. Install Xcode Command Line Tools."
  exit 1
fi

SDK="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macosx13.0"

mkdir -p "$MACOS_DIR" "$SAVER_BUNDLE/Contents/Resources"

xcrun swiftc \
  -emit-library \
  -Xlinker -bundle \
  -o "$BINARY" \
  -module-name MRXScreenSaver \
  -sdk "$SDK" \
  -F "$SDK/System/Library/Frameworks" \
  -framework ScreenSaver \
  -framework Cocoa \
  -framework QuartzCore \
  -target "$TARGET" \
  "$SWIFT_SRC"

chmod +x "$BINARY"

# Optional: keep web assets for browser/Tauri; not required by the native saver.
if [[ -d "$ROOT/dist" ]]; then
  rm -rf "$WWW_DIR"
  mkdir -p "$WWW_DIR"
  cp -R "$ROOT/dist/." "$WWW_DIR/" 2>/dev/null || true
fi

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep -s - "$SAVER_BUNDLE" 2>/dev/null || true
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 0.1.4" "$SAVER_BUNDLE/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 5" "$SAVER_BUNDLE/Contents/Info.plist" 2>/dev/null || true

echo "✅ Built: $SAVER_BUNDLE ($(file -b "$BINARY"))"

# Install into user Screen Savers
USER_SAVER="$HOME/Library/Screen Savers/MRXScreenSaver.saver"
mkdir -p "$HOME/Library/Screen Savers"
rm -rf "$USER_SAVER"
cp -R "$SAVER_BUNDLE" "$USER_SAVER"
xattr -dr com.apple.quarantine "$USER_SAVER" 2>/dev/null || true
codesign --force --deep -s - "$USER_SAVER" 2>/dev/null || true

# Point preferences at the working user copy; disable large clock overlay
defaults -currentHost write com.apple.screensaver showClock -bool false
defaults -currentHost write com.apple.screensaver moduleDict -dict \
  moduleName "MRX ScreenSaver" \
  path "$USER_SAVER" \
  type -int 0

# Force the host to drop the old mmap'd binary
killall legacyScreenSaver 2>/dev/null || true
killall ScreenSaverEngine 2>/dev/null || true

echo ""
echo "Installed → $USER_SAVER"
echo ""
echo "NEXT STEPS (important):"
echo "  1) If this exists, remove the EMPTY system copy:"
echo "       sudo rm -rf \"/Library/Screen Savers/MRXScreenSaver.saver\""
echo "  2) System Settings → Screen Saver → select MRX ScreenSaver → Preview"
echo "  3) Make sure 'Show large clock' is OFF"

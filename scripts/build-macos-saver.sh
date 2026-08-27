#!/usr/bin/env bash
# Build frontend assets + compile the macOS .saver bundle binary.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SAVER_BUNDLE="$ROOT/macos/MRXScreenSaver.saver"
WWW_DIR="$SAVER_BUNDLE/Contents/Resources/www"
MACOS_DIR="$SAVER_BUNDLE/Contents/MacOS"
SWIFT_SRC="$ROOT/macos/ScreenSaverView.swift"
BINARY="$MACOS_DIR/MRXScreenSaver"

echo "📦 Building frontend (relative base for file://)..."
npm run build

echo "📁 Syncing assets into .saver Resources/www..."
rm -rf "$WWW_DIR"
mkdir -p "$WWW_DIR" "$MACOS_DIR"
cp -R "$ROOT/dist/." "$WWW_DIR/"

# Sanity: index must exist and assets must be relative
if [[ ! -f "$WWW_DIR/index.html" ]]; then
  echo "❌ dist/index.html missing after build"
  exit 1
fi
if grep -q 'src="/assets/' "$WWW_DIR/index.html"; then
  echo "❌ Built index.html still uses absolute /assets paths — check vite base: './'"
  exit 1
fi

echo "🍎 Compiling ScreenSaver binary..."
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "❌ swiftc not found. Install Xcode Command Line Tools."
  exit 1
fi

SDK="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macosx13.0"

# ScreenSaver plugins must be Mach-O bundles (MH_BUNDLE), not dylibs.
xcrun swiftc \
  -emit-library \
  -Xlinker -bundle \
  -o "$BINARY" \
  -module-name MRXScreenSaver \
  -sdk "$SDK" \
  -F "$SDK/System/Library/Frameworks" \
  -framework ScreenSaver \
  -framework WebKit \
  -framework Cocoa \
  -target "$TARGET" \
  "$SWIFT_SRC"

chmod +x "$BINARY"

# Ad-hoc sign so System Settings can load the bundle locally.
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep -s - "$SAVER_BUNDLE" 2>/dev/null || true
fi

# Update version in Info.plist if present
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 0.1.2" "$SAVER_BUNDLE/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 3" "$SAVER_BUNDLE/Contents/Info.plist" 2>/dev/null || true

echo ""
echo "✅ Built: $SAVER_BUNDLE"
echo "   Binary: $BINARY ($(file -b "$BINARY"))"
echo "   Assets: $WWW_DIR"
echo ""
echo "Install:"
echo "  1. Double-click macos/MRXScreenSaver.saver"
echo "     OR: cp -R \"$SAVER_BUNDLE\" ~/Library/Screen\\ Savers/"
echo "  2. System Settings → Screen Saver → choose MRX ScreenSaver"
echo "  3. If blocked: System Settings → Privacy & Security → Open Anyway"

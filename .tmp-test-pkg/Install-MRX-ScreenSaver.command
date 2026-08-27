#!/bin/bash
# Install MRXScreenSaver.saver from the folder containing this script.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$DIR/MRXScreenSaver.saver"
DEST="$HOME/Library/Screen Savers/MRXScreenSaver.saver"

if [[ ! -d "$SRC" ]]; then
  echo "MRXScreenSaver.saver not found next to this installer."
  echo "Unzip the full MRXScreenSaver-macOS.zip first."
  read -r -p "Press Enter to close…"
  exit 1
fi

echo "Installing MRX ScreenSaver…"
mkdir -p "$HOME/Library/Screen Savers"
rm -rf "$DEST"
cp -R "$SRC" "$DEST"

# Chrome/GitHub downloads add quarantine → "damaged" dialog + black preview.
xattr -cr "$DEST" 2>/dev/null || true
xattr -d com.apple.quarantine "$DEST" 2>/dev/null || true

# Re-sign after copy (ad-hoc — open-source distribution).
codesign --force --sign - --timestamp=none "$DEST/Contents/MacOS/MRXScreenSaver" 2>/dev/null || true
codesign --force --deep --sign - --timestamp=none "$DEST" 2>/dev/null || true

defaults -currentHost write com.apple.screensaver showClock -bool false
defaults -currentHost write com.apple.screensaver moduleDict -dict \
  moduleName "MRX ScreenSaver" \
  path "$DEST" \
  type -int 0

killall legacyScreenSaver "Screen Saver" ScreenSaverEngine 2>/dev/null || true

echo ""
echo "Installed → $DEST"
echo "Open System Settings → Screen Saver → MRX ScreenSaver → Preview"
echo ""
read -r -p "Press Enter to close…"

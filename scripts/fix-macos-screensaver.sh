#!/usr/bin/env bash
# One-shot repair for black-screen MRX ScreenSaver installs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Building native saver..."
bash "$ROOT/scripts/build-macos-saver.sh"

echo ""
echo "Removing broken system-wide empty saver (needs password)..."
if [[ -d "/Library/Screen Savers/MRXScreenSaver.saver" ]]; then
  if sudo rm -rf "/Library/Screen Savers/MRXScreenSaver.saver"; then
    echo "Removed /Library/Screen Savers/MRXScreenSaver.saver"
  else
    echo "WARNING: could not remove system copy — run manually:"
    echo "  sudo rm -rf \"/Library/Screen Savers/MRXScreenSaver.saver\""
  fi
else
  echo "No system copy present (good)."
fi

defaults -currentHost write com.apple.screensaver showClock -bool false
killall legacyScreenSaver 2>/dev/null || true
killall ScreenSaverEngine 2>/dev/null || true

echo ""
echo "Done. Open System Settings → Screen Saver → MRX ScreenSaver → Preview."
echo "Confirm 'Show large clock' is OFF."

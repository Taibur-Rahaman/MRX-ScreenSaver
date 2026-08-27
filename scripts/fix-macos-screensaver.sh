#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
bash "$ROOT/scripts/build-macos-saver.sh"
echo ""
echo "Removing broken system-wide empty saver (needs password)..."
if [[ -d "/Library/Screen Savers/MRXScreenSaver.saver" ]]; then
  sudo rm -rf "/Library/Screen Savers/MRXScreenSaver.saver" && echo "Removed system copy." || echo "Could not remove — run sudo manually."
else
  echo "No system copy present."
fi
killall legacyScreenSaver "Screen Saver" ScreenSaverEngine 2>/dev/null || true
echo "Open System Settings → Screen Saver → MRX ScreenSaver → Preview"

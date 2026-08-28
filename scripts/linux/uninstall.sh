#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${HOME}/.local/share/mrx-screensaver"
BIN_LINK="${HOME}/.local/bin/mrx-screensaver"
DESKTOP="${HOME}/.local/share/applications/mrx-screensaver.desktop"

rm -f "$BIN_LINK" "$DESKTOP"
rm -rf "$INSTALL_DIR"

if [[ -f "${HOME}/.xscreensaver" ]]; then
  sed -i.bak '/mrx-screensaver/d' "${HOME}/.xscreensaver" 2>/dev/null || true
fi

echo "✅ MRX ScreenSaver removed."

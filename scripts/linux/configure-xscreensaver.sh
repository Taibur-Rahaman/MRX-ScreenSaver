#!/usr/bin/env bash
# Register mrx-screensaver with XScreenSaver (if installed).
set -euo pipefail

if ! command -v xscreensaver >/dev/null 2>&1; then
  echo "ℹ️  XScreenSaver not found. Install with: sudo apt install xscreensaver"
  echo "   You can still run: mrx-screensaver"
  exit 0
fi

CFG="${HOME}/.xscreensaver"
LINE='        MRX Flip Clock          mrx-screensaver \n\'

if [[ -f "$CFG" ]] && grep -q 'mrx-screensaver' "$CFG"; then
  echo "✅ XScreenSaver already configured for MRX Flip Clock."
  exit 0
fi

if [[ ! -f "$CFG" ]]; then
  xscreensaver -no-splash >/dev/null 2>&1 || true
fi

if [[ ! -f "$CFG" ]]; then
  echo "⚠️  Could not create ~/.xscreensaver automatically."
  echo "   In XScreenSaver Settings → Advanced → Programs, add:"
  echo "   Name: MRX Flip Clock   Command: mrx-screensaver"
  exit 0
fi

if grep -q '^programs:' "$CFG"; then
  # Insert after the programs: line
  awk -v line="$LINE" '
    /^programs:/ { print; print line; next }
    { print }
  ' "$CFG" >"${CFG}.new" && mv "${CFG}.new" "$CFG"
else
  {
    echo 'programs: \'
    echo "$LINE"
  } >>"$CFG"
fi

echo "✅ Added 'MRX Flip Clock' to XScreenSaver."
echo "   Open XScreenSaver Settings → choose MRX Flip Clock → Preview."
if command -v xscreensaver-settings >/dev/null 2>&1; then
  xscreensaver-settings >/dev/null 2>&1 &
fi

#!/usr/bin/env bash
# Install MRX ScreenSaver for Linux (Ubuntu/Debian and most distros with WebKitGTK).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${HOME}/.local/share/mrx-screensaver"
BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"

install_dependencies() {
  echo "Checking Linux dependencies..."
  if command -v apt-get >/dev/null 2>&1; then
    local missing=()
    for pkg in libwebkit2gtk-4.1-0 libjavascriptcoregtk-4.1-0 libgtk-3-0; do
      dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done
    if ((${#missing[@]} > 0)); then
      echo "Installing: ${missing[*]}"
      sudo apt-get update -qq
      sudo apt-get install -y "${missing[@]}" libayatana-appindicator3-1 2>/dev/null \
        || sudo apt-get install -y libwebkit2gtk-4.1-0 libjavascriptcoregtk-4.1-0 libgtk-3-0
    fi
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y webkit2gtk4.1 gtk3 libappindicator-gtk3 2>/dev/null || true
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --needed webkit2gtk-4.1 gtk3 libappindicator-gtk3 2>/dev/null || true
  elif command -v zypper >/dev/null 2>&1; then
    sudo zypper install -y libwebkit2gtk-4.1-0 libgtk-3-0 typelib-1_0-AyatanaAppIndicator3-0.1 2>/dev/null || true
  else
    echo "ℹ️  Install WebKitGTK 4.1 manually if the app fails to start."
  fi
}

pick_binary() {
  if [[ -f "$ROOT/MRXScreenSaver" ]]; then
    echo "$ROOT/MRXScreenSaver"
    return
  fi
  local appimage
  appimage="$(find "$ROOT" -maxdepth 1 -name '*.AppImage' | head -n 1 || true)"
  if [[ -n "$appimage" ]]; then
    echo "$appimage"
    return
  fi
  echo ""
}

install_dependencies

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DESKTOP_DIR"

SRC="$(pick_binary)"
if [[ -z "$SRC" ]]; then
  echo "❌ No MRXScreenSaver binary or AppImage found next to install.sh"
  exit 1
fi

if [[ "$SRC" == *.AppImage ]]; then
  cp "$SRC" "$INSTALL_DIR/MRXScreenSaver.AppImage"
  chmod +x "$INSTALL_DIR/MRXScreenSaver.AppImage"
  cat >"$INSTALL_DIR/mrx-screensaver" <<'EOF'
#!/usr/bin/env bash
exec "$HOME/.local/share/mrx-screensaver/MRXScreenSaver.AppImage" "$@"
EOF
  chmod +x "$INSTALL_DIR/mrx-screensaver"
else
  cp "$SRC" "$INSTALL_DIR/MRXScreenSaver"
  chmod +x "$INSTALL_DIR/MRXScreenSaver"
  ln -sf "$INSTALL_DIR/MRXScreenSaver" "$INSTALL_DIR/mrx-screensaver"
fi

ln -sf "$INSTALL_DIR/mrx-screensaver" "$BIN_DIR/mrx-screensaver"

cat >"$DESKTOP_DIR/mrx-screensaver.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=MRX ScreenSaver
Comment=Flipqlo-style flip clock screensaver
Exec=${INSTALL_DIR}/mrx-screensaver
Icon=preferences-desktop-screensaver
Terminal=false
Categories=Utility;Screensaver;
StartupNotify=false
EOF

if [[ -f "$ROOT/configure-xscreensaver.sh" ]]; then
  bash "$ROOT/configure-xscreensaver.sh" || true
fi

echo "✅ MRX ScreenSaver installed to $INSTALL_DIR"
echo "   Run: mrx-screensaver"

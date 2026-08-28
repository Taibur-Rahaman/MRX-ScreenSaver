#!/usr/bin/env bash
# Prepare release assets: macOS .saver (local) and notes for Windows .scr (CI).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="$ROOT/release-assets"
rm -rf "$OUT"
mkdir -p "$OUT"

echo "🚀 Preparing release assets..."

echo "📦 Building frontend..."
npm run build

# macOS .saver
if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "🍎 Building macOS .saver..."
  bash "$ROOT/scripts/build-macos-saver.sh"
  PKG="$OUT/macos-pkg"
  rm -rf "$PKG"
  mkdir -p "$PKG"
  cp -R "$ROOT/macos/MRXScreenSaver.saver" "$PKG/"
  cp "$ROOT/scripts/macos/Install-MRX-ScreenSaver.command" "$PKG/"
  cp "$ROOT/scripts/macos/README-macOS.txt" "$PKG/"
  chmod +x "$PKG/Install-MRX-ScreenSaver.command"
  xattr -cr "$PKG/MRXScreenSaver.saver"
  codesign --force --sign - --timestamp=none "$PKG/MRXScreenSaver.saver/Contents/MacOS/MRXScreenSaver" 2>/dev/null || true
  codesign --force --deep --sign - --timestamp=none "$PKG/MRXScreenSaver.saver" 2>/dev/null || true
  (cd "$PKG" && zip -r "$OUT/MRXScreenSaver-macOS.zip" . -x "*.DS_Store")
  cp "$PKG/Install-MRX-ScreenSaver.command" "$OUT/"
  cp "$PKG/README-macOS.txt" "$OUT/"
  echo "✅ $OUT/MRXScreenSaver-macOS.zip (+ Install-MRX-ScreenSaver.command)"
fi

# Windows .scr — only when building on Windows (or via GitHub Actions)
if [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* || "${RUNNER_OS:-}" == "Windows" ]]; then
  echo "🪟 Building Windows screensaver (.scr)..."
  npm run tauri build

  EXE=""
  for candidate in \
    "src-tauri/target/release/MRXScreenSaver.exe" \
    "src-tauri/target/release/mrx-screensaver.exe" \
    "src-tauri/target/release/app.exe"
  do
    if [[ -f "$candidate" ]]; then
      EXE="$candidate"
      break
    fi
  done

  if [[ -z "$EXE" ]]; then
    EXE="$(find src-tauri/target/release -maxdepth 1 -name '*.exe' ! -name '*.pdb' | head -n 1 || true)"
  fi

  if [[ -n "$EXE" && -f "$EXE" ]]; then
    cp "$EXE" "$OUT/MRXScreenSaver.scr"
    echo "✅ $OUT/MRXScreenSaver.scr"
  else
    echo "❌ Could not find Windows .exe after tauri build"
    exit 1
  fi
else
  echo "ℹ️  Windows .scr is built by GitHub Actions on windows-latest (tag push)."
fi

# Linux — only when building on Linux (or via GitHub Actions)
if [[ "$(uname -s)" == "Linux" && "${RUNNER_OS:-Linux}" != "Windows" ]]; then
  echo "🐧 Building Linux screensaver..."
  npm run tauri build -- --bundles appimage 2>/dev/null || npx tauri build --bundles appimage

  PKG="$OUT/linux-pkg"
  rm -rf "$PKG"
  mkdir -p "$PKG"

  BIN=""
  for candidate in \
    "src-tauri/target/release/MRXScreenSaver" \
    "src-tauri/target/release/mrx-screensaver"
  do
    if [[ -f "$candidate" ]]; then
      BIN="$candidate"
      break
    fi
  done
  [[ -n "$BIN" ]] && cp "$BIN" "$PKG/MRXScreenSaver" && chmod +x "$PKG/MRXScreenSaver"

  APPIMAGE="$(find src-tauri/target/release/bundle/appimage -name '*.AppImage' 2>/dev/null | head -n 1 || true)"
  [[ -n "$APPIMAGE" ]] && cp "$APPIMAGE" "$PKG/"

  cp scripts/linux/install.sh scripts/linux/uninstall.sh scripts/linux/configure-xscreensaver.sh scripts/linux/README-Linux.txt "$PKG/"
  mv "$PKG/README-Linux.txt" "$PKG/README.txt"
  chmod +x "$PKG"/*.sh
  (cd "$PKG" && zip -r "$OUT/MRXScreenSaver-Linux.zip" .)
  echo "✅ $OUT/MRXScreenSaver-Linux.zip"
else
  echo "ℹ️  Linux zip is built by GitHub Actions on ubuntu-latest (tag push)."
fi

echo "🎉 Assets in $OUT"
ls -la "$OUT"

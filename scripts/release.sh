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
  echo "✅ $OUT/MRXScreenSaver-macOS.zip"
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

echo "🎉 Assets in $OUT"
ls -la "$OUT"

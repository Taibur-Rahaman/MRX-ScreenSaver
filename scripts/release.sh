#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "🚀 Starting Release Process..."

# 1. Always build the web frontend for packaging
echo "📦 Building frontend..."
npm run build

# 2. Windows Post-Processing
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    echo "🪟 Processing Windows screensaver..."
    if command -v npm >/dev/null 2>&1; then
      npm run tauri build || true
    fi
    EXE_PATH=$(find src-tauri/target/release/bundle -name "*.exe" 2>/dev/null | head -n 1 || true)
    if [ -n "$EXE_PATH" ]; then
        SCR_PATH="${EXE_PATH%.exe}.scr"
        cp "$EXE_PATH" "$SCR_PATH"
        echo "✅ Created: $SCR_PATH"
    else
        echo "⚠️  Could not find .exe for Windows release (Tauri build may be required)"
    fi
fi

# 3. macOS .saver bundle
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🍎 Building macOS .saver..."
    bash "$ROOT/scripts/build-macos-saver.sh"
fi

echo "🎉 Release assets prepared!"

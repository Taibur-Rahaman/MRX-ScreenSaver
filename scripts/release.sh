#!/bin/bash
set -e

echo "🚀 Starting Release Process..."

# 1. Build the Tauri Application
echo "📦 Building Tauri binary..."
npm run tauri build

# 2. Windows Post-Processing
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    echo "🪟 Processing Windows screensaver..."
    BUILD_DIR="src-tauri/target/release/bundle/msi" # This path varies by tauri version/config
    # Search for the exe in the build output
    EXE_PATH=$(find src-tauri/target/release/bundle -name "*.exe" | head -n 1)
    if [ -n "$EXE_PATH" ]; then
        SCR_PATH="${EXE_PATH%.exe}.scr"
        cp "$EXE_PATH" "$SCR_PATH"
        echo "✅ Created: $SCR_PATH"
    else
        echo "❌ Could not find .exe for Windows release"
    fi
fi

# 3. macOS Post-Processing
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🍎 Processing macOS screensaver..."
    SAVER_BUNDLE="macos/MRXScreenSaver.saver"
    ASSETS_DIR="src/dist" # Assuming vite build output

    # Build frontend assets first
    npm run build

    # Copy assets to the saver bundle
    mkdir -p "$SAVER_BUNDLE/Contents/Resources/www"
    cp -r src/dist/* "$SAVER_BUNDLE/Contents/Resources/www/"
    echo "✅ Assets copied to $SAVER_BUNDLE"
    echo "⚠️  Reminder: Build the MRXScreenSaver binary in Xcode and place it in $SAVER_BUNDLE/Contents/MacOS/"
fi

echo "🎉 Release assets prepared!"

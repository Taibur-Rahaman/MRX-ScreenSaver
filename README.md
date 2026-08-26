# 🌌 MRX ScreenSaver

A high-performance, cross-platform screensaver powered by **Tauri**, **WebGL 2**, and **TypeScript**.

## 🚀 Features
- **Cross-Platform**: Native `.scr` for Windows and `.saver` for macOS.
- **WebGL Core**: Hardware-accelerated animations for smooth, high-frame-rate visuals.
- **Operational Modes**: Dedicated modes for Full-screen, Preview, and Settings.
- **Persistence**: User preferences saved locally via Tauri Store.

## 🛠️ Development

### Prerequisites
- [Rust](https://www.rust-lang.org/tools/install)
- [Node.js](https://nodejs.org/)
- [Tauri Prerequisites](https://tauri.app/start/prerequisites/)

### Installation
\`\`\`bash
npm install
\`\`\`

### Running in Dev Mode
\`\`\`bash
npm run tauri dev
\`\`\`
To test specific modes, append query parameters to the URL (if using a browser) or modify `main.rs` default flags:
- `?mode=screensaver`
- `?mode=preview`
- `?mode=settings`

## 📦 Release Process

The release process is automated via `npm run release`, which executes `scripts/release.sh`.

### Windows Release
1. Run `npm run release`.
2. The script builds the Tauri binary and renames it to `MRXScreenSaver.scr`.
3. Install by right-clicking the `.scr` file and selecting **Install**.

### macOS Release
1. Run `npm run release`. This builds the frontend assets and copies them into the `.saver` bundle.
2. **Native Compilation**:
   - Open the project in Xcode.
   - Compile the `ScreenSaverView.swift` code into a Mach-O bundle binary.
   - Place the resulting binary in `macos/MRXScreenSaver.saver/Contents/MacOS/MRXScreenSaver`.
3. Install by double-clicking the `.saver` bundle.

## 📁 Project Structure
- `src/core/`: Rendering engine and scene management.
- `src/core/scenes/`: Individual animation implementations.
- `src-tauri/`: Rust backend for window management and system integration.
- `macos/`: Native Swift wrapper and bundle configuration.
- `assets/`: Shaders and visual resources.

# 🌌 MRX ScreenSaver

A high-performance, cross-platform screensaver powered by **Tauri**, **WebGL 2**, and **TypeScript**.

Created by **[MRX](https://github.com/Taibur-Rahaman/)**.

## 🚀 Features
- **Flip Clock**: Flipqlo-style split-flap clock with per-digit animation, AM/PM, and date.
- **Starfield**: Hardware-accelerated WebGL starfield scene.
- **Cross-Platform**: Native `.scr` for Windows and `.saver` for macOS.
- **Operational Modes**: Full-screen, Preview, and Settings.
- **Persistence**: User preferences saved locally via Tauri Store.

## 🛠️ Development

### Prerequisites
- [Rust](https://www.rust-lang.org/tools/install)
- [Node.js](https://nodejs.org/)
- [Tauri Prerequisites](https://tauri.app/start/prerequisites/)

### Installation
```bash
npm install
```

### Running in Dev Mode
```bash
npm run tauri dev
```

Browser preview:
```bash
npm run dev
```

Then open:
- Flip clock: `http://localhost:1420/?scene=flipclock`
- Starfield: `http://localhost:1420/?scene=starfield`

Query parameters:
- `?mode=screensaver`
- `?mode=preview`
- `?mode=settings`
- `?scene=flipclock` / `?scene=starfield`

### macOS Screen Saver install

The macOS `.saver` is a **native** Flipqlo-style flip clock (Core Graphics).  
It does **not** use WKWebView — WebKit black-screens inside `legacyScreenSaver` on Sonoma+.

```bash
npm run build:macos-saver
# or:
bash scripts/fix-macos-screensaver.sh
```

Then run these exactly:

```bash
# CRITICAL — remove the empty broken system install
sudo rm -rf "/Library/Screen Savers/MRXScreenSaver.saver"

# Force macOS to reload the saver host
killall legacyScreenSaver ScreenSaverEngine 2>/dev/null

# Keep the big system clock overlay OFF
defaults -currentHost write com.apple.screensaver showClock -bool false
```

Open **System Settings → Screen Saver → MRX ScreenSaver → Preview**.

If macOS blocks it: **Privacy & Security → Open Anyway**.

Browser / Tauri still use the web Flip Clock via `?scene=flipclock`.

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
- `src/core/scenes/`: Individual animation implementations (flip clock, starfield).
- `src-tauri/`: Rust backend for window management and system integration.
- `macos/`: Native Swift wrapper and bundle configuration.
- `assets/`: Shaders and visual resources.

## 👤 Credit
**MRX** — [github.com/Taibur-Rahaman](https://github.com/Taibur-Rahaman/)

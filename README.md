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

```bash
npm run build:macos-saver
```

Then either double-click `macos/MRXScreenSaver.saver`, or:

```bash
cp -R macos/MRXScreenSaver.saver ~/Library/Screen\ Savers/
xattr -dr com.apple.quarantine ~/Library/Screen\ Savers/MRXScreenSaver.saver
```

Open **System Settings → Screen Saver**, select **MRX ScreenSaver**, and preview it.

**Important — avoid the black system clock overlay:**
1. In Screen Saver settings, turn **off** “Show large clock” / clock overlay if present.
2. Or run:
   ```bash
   defaults -currentHost write com.apple.screensaver showClock -bool false
   ```
3. If you previously installed an empty bundle to `/Library/Screen Savers/`, remove it (it loads instead of the working one):
   ```bash
   sudo rm -rf "/Library/Screen Savers/MRXScreenSaver.saver"
   cp -R macos/MRXScreenSaver.saver ~/Library/Screen\ Savers/
   ```

If macOS blocks the saver: **Privacy & Security → Open Anyway**.

The macOS saver always loads the **flip clock** scene (injected by the native host). For browser testing use `?scene=flipclock`.

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

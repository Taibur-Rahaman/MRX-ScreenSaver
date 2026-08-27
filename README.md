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

**From GitHub release:** unzip `MRXScreenSaver-macOS.zip` and double-click  
`Install-MRX-ScreenSaver.command`.  
Do **not** double-click `MRXScreenSaver.saver` after a Chrome download — macOS shows  
“damaged” and Preview stays black.

**From source:**
```bash
npm run build:macos-saver
# or:
bash scripts/fix-macos-screensaver.sh
```

If you must install manually after download:
```bash
cp -R MRXScreenSaver.saver ~/Library/Screen\ Savers/
xattr -cr ~/Library/Screen\ Savers/MRXScreenSaver.saver
codesign --force --deep -s - --timestamp=none ~/Library/Screen\ Savers/MRXScreenSaver.saver
```

Then:
```bash
sudo rm -rf "/Library/Screen Savers/MRXScreenSaver.saver"
killall legacyScreenSaver ScreenSaverEngine 2>/dev/null
defaults -currentHost write com.apple.screensaver showClock -bool false
```

Open **System Settings → Screen Saver → MRX ScreenSaver → Preview**.

Browser / Tauri still use the web Flip Clock via `?scene=flipclock`.

## 📦 Release Process

Push a version tag (or run **Release** workflow manually). GitHub Actions builds and attaches:

| Asset | Platform |
|-------|----------|
| `MRXScreenSaver-Windows.zip` | Windows (Install.bat + .scr) |
| `MRXScreenSaver.scr` | Windows |
| `MRXScreenSaver-macOS.zip` | macOS (Install command + .saver) |

```bash
git tag v0.1.8 && git push origin v0.1.8
```

Local packaging helpers:
```bash
npm run release          # macOS .saver zip (on Mac); Windows .scr when run on Windows
npm run build:macos-saver
```

### Windows install
1. Download **MRXScreenSaver-Windows.zip** from the release and unzip.
2. Double-click **Install.bat**, or right-click `MRXScreenSaver.scr` → **Install**.
3. Choose **MRXScreenSaver** in Screen Saver Settings → Apply.
4. Requires [WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/) (usually already on Windows 11).

Test without installing: double-click `MRXScreenSaver.scr` (mouse/key exits).

### macOS install
1. Download **MRXScreenSaver-macOS.zip**, unzip.
2. Double-click **Install-MRX-ScreenSaver.command** (do not open the .saver directly after Chrome download).
3. System Settings → Screen Saver → MRX ScreenSaver → Preview.
4. If needed: `sudo rm -rf "/Library/Screen Savers/MRXScreenSaver.saver"`

Browser / Tauri still use the web Flip Clock via `?scene=flipclock`.

## 📁 Project Structure
- `src/core/`: Rendering engine and scene management.
- `src/core/scenes/`: Individual animation implementations (flip clock, starfield).
- `src-tauri/`: Rust/Tauri backend — Windows `.scr` packaging.
- `macos/`: Native Objective-C Flipqlo `.saver` bundle.
- `.github/workflows/release.yml`: Builds macOS + Windows release assets.
- `assets/`: Shaders and visual resources.

## 👤 Credit
**MRX** — [github.com/Taibur-Rahaman](https://github.com/Taibur-Rahaman/)

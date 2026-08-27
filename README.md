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

Push a version tag (or run **Release** workflow manually). GitHub Actions builds and attaches:

| Asset | Platform |
|-------|----------|
| `MRXScreenSaver-macOS.saver.zip` | macOS |
| `MRXScreenSaver.scr` | Windows |

```bash
git tag v0.1.8 && git push origin v0.1.8
```

Local packaging helpers:
```bash
npm run release          # macOS .saver zip (on Mac); Windows .scr when run on Windows
npm run build:macos-saver
```

### Windows install
1. Download **MRXScreenSaver.scr** from the release.
2. Right-click → **Install**.
3. Choose it in **Screen Saver Settings**.
4. Preview / Apply.

### macOS install
1. Download **MRXScreenSaver-macOS.saver.zip**, unzip.
2. Double-click `MRXScreenSaver.saver`, or run `npm run build:macos-saver`.
3. Remove any broken system copy if needed:
   `sudo rm -rf "/Library/Screen Savers/MRXScreenSaver.saver"`

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

# MRX ScreenSaver

[![Latest Release](https://img.shields.io/github/v/release/Taibur-Rahaman/MRX-ScreenSaver?style=flat-square)](https://github.com/Taibur-Rahaman/MRX-ScreenSaver/releases/latest)
[![Release](https://github.com/Taibur-Rahaman/MRX-ScreenSaver/actions/workflows/release.yml/badge.svg)](https://github.com/Taibur-Rahaman/MRX-ScreenSaver/actions/workflows/release.yml)
[![Web Demo](https://img.shields.io/badge/demo-live%20flip%20clock-0A0A0A?style=flat-square)](https://taibur-rahaman.github.io/MRX-ScreenSaver/?scene=flipclock)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)

A **Flipqlo-style flip clock screensaver** for **Windows**, **macOS**, **Linux**, and the **web**.

Created by **[MRX](https://github.com/Taibur-Rahaman/)**.

---

## Try it now (no install)

> **Use this exact URL** (case-sensitive path):  
> **https://taibur-rahaman.github.io/MRX-ScreenSaver/?scene=flipclock**  
> `taibur-rahaman.github.io` alone will show a GitHub 404 — the `/MRX-ScreenSaver/` part is required.

| Scene | Live demo |
|-------|-----------|
| Flip Clock | [Open flip clock](https://taibur-rahaman.github.io/MRX-ScreenSaver/?scene=flipclock) |
| Starfield | [Open starfield](https://taibur-rahaman.github.io/MRX-ScreenSaver/?scene=starfield) |

---

## Download

**[Latest release →](https://github.com/Taibur-Rahaman/MRX-ScreenSaver/releases/latest)**

| Platform | Download | Install |
|----------|----------|---------|
| **Windows** | [MRXScreenSaver-Windows.zip](https://github.com/Taibur-Rahaman/MRX-ScreenSaver/releases/latest/download/MRXScreenSaver-Windows.zip) | Run `Install.bat` as administrator |
| **macOS** | [MRXScreenSaver-macOS.zip](https://github.com/Taibur-Rahaman/MRX-ScreenSaver/releases/latest/download/MRXScreenSaver-macOS.zip) | Run `Install-MRX-ScreenSaver.command` |
| **Linux** | [MRXScreenSaver-Linux.zip](https://github.com/Taibur-Rahaman/MRX-ScreenSaver/releases/latest/download/MRXScreenSaver-Linux.zip) | Run `bash install.sh` |
| **Web** | [Live demo](https://taibur-rahaman.github.io/MRX-ScreenSaver/?scene=flipclock) | Works in any modern browser |

---

## Screenshots

### Flip Clock (Flipqlo-style)

![Flip clock screensaver preview](https://raw.githubusercontent.com/Taibur-Rahaman/MRX-ScreenSaver/main/docs/screenshots/flipclock-preview.svg)

### Starfield

![Starfield screensaver preview](https://raw.githubusercontent.com/Taibur-Rahaman/MRX-ScreenSaver/main/docs/screenshots/starfield-preview.svg)

---

## Features

- **Flip Clock** — Split-flap digits with per-digit animation, AM/PM, date, and Flipqlo-aligned design tokens
- **Starfield** — Hardware-accelerated WebGL starfield (web / Tauri hosts)
- **Cross-platform** — Native `.scr` (Windows), `.saver` (macOS), AppImage/binary (Linux), and browser demo
- **Modes** — Full-screen run, preview embed, and settings
- **Offline-safe** — macOS uses native Core Graphics (no WebKit black-screen on Sonoma+)

---

## Windows install

1. Download **[MRXScreenSaver-Windows.zip](https://github.com/Taibur-Rahaman/MRX-ScreenSaver/releases/latest/download/MRXScreenSaver-Windows.zip)** and unzip.
2. Right-click **Install.bat** → **Run as administrator** (copies to System32).
3. Open the **classic** Screen Saver dialog: `Win+R` → `control desk.cpl,,1` (or use `Open-Screen-Saver-Settings.bat`).
4. Choose **MRXScreenSaver** → **Preview**.

> **Note:** Windows 11 Settings → Personalization only lists built-in savers. Use the classic dialog above.

Requires [WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/) (pre-installed on most Windows 11 systems).

---

## macOS install

1. Download **[MRXScreenSaver-macOS.zip](https://github.com/Taibur-Rahaman/MRX-ScreenSaver/releases/latest/download/MRXScreenSaver-macOS.zip)** and unzip.
2. Double-click **Install-MRX-ScreenSaver.command** (do **not** open the `.saver` directly after a browser download).
3. **System Settings → Screen Saver → MRX ScreenSaver → Preview**.

The macOS bundle is a **native** flip clock (Core Graphics) — not WebKit — so it works reliably on Sonoma and later.

---

## Linux / Ubuntu install

1. Download **[MRXScreenSaver-Linux.zip](https://github.com/Taibur-Rahaman/MRX-ScreenSaver/releases/latest/download/MRXScreenSaver-Linux.zip)** and unzip.
2. Run:
   ```bash
   bash install.sh
   ```
3. Launch from your app menu or terminal:
   ```bash
   mrx-screensaver
   ```

### XScreenSaver (recommended on Ubuntu)

```bash
sudo apt install xscreensaver
bash configure-xscreensaver.sh
```

Then open **XScreenSaver Settings** → select **MRX Flip Clock** → **Preview**.

Move the mouse or press any key to exit.

---

## Development

### Prerequisites

- [Node.js](https://nodejs.org/) 20+
- [Rust](https://www.rust-lang.org/tools/install) (for Tauri / Windows / Linux builds)
- [Tauri prerequisites](https://tauri.app/start/prerequisites/)

### Setup

```bash
npm install
```

### Browser dev server

```bash
npm run dev
```

- Flip clock: http://localhost:1420/?scene=flipclock
- Starfield: http://localhost:1420/?scene=starfield

### Tauri dev (Windows / Linux)

```bash
npm run tauri dev
```

### macOS native .saver

```bash
npm run build:macos-saver
```

### Build web demo locally

```bash
npm run build:web
```

---

## Query parameters

| Param | Values |
|-------|--------|
| `scene` | `flipclock`, `starfield` |
| `mode` | `screensaver`, `preview`, `settings` |
| `speed` | `0.1` – `5.0` |

Example: `?scene=flipclock&mode=screensaver`

---

## Release process

Push a version tag to build all platform assets:

```bash
git tag v0.1.18 && git push origin v0.1.18
```

GitHub Actions builds and publishes:

| Asset | Platform |
|-------|----------|
| `MRXScreenSaver-Windows.zip` | Windows `.scr` + installer |
| `MRXScreenSaver-macOS.zip` | macOS `.saver` + installer |
| `MRXScreenSaver-Linux.zip` | Linux AppImage/binary + scripts |
| Web demo | Auto-deployed to GitHub Pages on `main` |

---

## Project structure

```
src/                    TypeScript frontend (flip clock, starfield)
src-tauri/              Rust/Tauri — Windows .scr + Linux binary
macos/                  Native Objective-C .saver (macOS)
scripts/
  linux/                Linux install + XScreenSaver config
  macos/                macOS installer
  windows/              Windows installer
docs/screenshots/       README & social preview images
.github/workflows/      Release CI + GitHub Pages deploy
```

---

## Keywords

`screensaver` · `flip clock` · `flipqlo` · `windows scr` · `macos saver` · `linux screensaver` · `ubuntu xscreensaver` · `web screensaver` · `tauri` · `typescript`

---

## Credit

**MRX** — [github.com/Taibur-Rahaman](https://github.com/Taibur-Rahaman/)

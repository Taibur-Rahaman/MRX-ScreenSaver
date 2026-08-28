# MRX Flip Clock — Android

Standalone Android module (does not modify macOS / Windows / web sources).

## Features

- **Landscape** — `HH : MM : SS` horizontal flip clock
- **Portrait** — hours (+ AM/PM), minutes, seconds stacked vertically
- **Screen saver** — `FlipClockDreamService` (Settings → Display → Screen saver)
- **App preview** — launcher activity, tap to open screen saver settings

## Build APK

```bash
bash scripts/android/build-apk.sh
```

Requires **JDK 17** and **Android SDK** (`ANDROID_HOME`).

## Install on phone

1. Copy `MRXScreenSaver-Android.apk` to the device
2. Install APK
3. Enable screen saver: **Settings → Display → Screen saver → MRX Flip Clock**

See `scripts/android/README-Android.txt` for full instructions.

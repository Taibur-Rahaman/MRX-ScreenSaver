MRX Flip Clock — Android
========================

Flipqlo-style flip clock screen saver for Android phones.

Layouts (auto-rotate)
---------------------
- **Landscape** — HH : MM : SS in a horizontal row (like the reference image).
- **Portrait** — hours (+ AM/PM), minutes, and seconds stacked vertically.

Install APK
-----------
1. Download **MRXScreenSaver-Android.apk** from GitHub Releases.
2. On your phone: allow install from unknown sources if prompted.
3. Open the APK and install.

Use as screen saver (while charging / docked)
---------------------------------------------
Android uses **Screen saver** (Daydream), not a custom lockscreen on modern versions:

1. **Settings → Display → Screen saver** (or search "Screen saver")
2. Choose **MRX Flip Clock**
3. Set when to start (e.g. while charging)
4. Tap **Preview** or place on charger

Preview in app
--------------
Open **MRX Flip Clock** from the launcher — fullscreen preview. Rotate for landscape/portrait.

Build from source
-----------------
```bash
bash scripts/android/build-apk.sh
```

Requires JDK 17+ and Android SDK (or run via GitHub Actions on tag push).

Note: Replacing the system lockscreen UI is restricted on Android 10+. This app provides the official screen saver + live preview.

Created by MRX — https://github.com/Taibur-Rahaman/MRX-ScreenSaver

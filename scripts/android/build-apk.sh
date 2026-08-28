#!/usr/bin/env bash
# Build MRX Flip Clock Android APK (debug or release).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID="$ROOT/android"

if [[ ! -d "$ANDROID" ]]; then
  echo "android/ project not found"
  exit 1
fi

cd "$ANDROID"

if [[ ! -x "$ANDROID/gradlew" ]]; then
  GRADLE_VER=8.7
  curl -fsSL "https://services.gradle.org/distributions/gradle-${GRADLE_VER}-bin.zip" -o /tmp/gradle.zip
  unzip -q /tmp/gradle.zip -d /tmp
  (cd "$ANDROID" && /tmp/gradle-${GRADLE_VER}/bin/gradle wrapper --gradle-version "$GRADLE_VER")
fi

chmod +x "$ANDROID/gradlew"
cd "$ANDROID"
./gradlew assembleRelease

OUT="$ROOT/release-assets"
mkdir -p "$OUT"
APK="$(find app/build/outputs/apk/release -name '*.apk' | head -n 1)"
if [[ -z "$APK" ]]; then
  echo "APK not found"
  exit 1
fi

cp "$APK" "$OUT/MRXScreenSaver-Android.apk"
echo "✅ $OUT/MRXScreenSaver-Android.apk"

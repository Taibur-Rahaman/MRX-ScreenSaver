MRX ScreenSaver — macOS install

DO NOT double-click MRXScreenSaver.saver after downloading from Chrome/GitHub.
macOS will show "damaged" and the screen saver will stay black.

Install (recommended):
  1. Unzip MRXScreenSaver-macOS.zip
  2. Double-click Install-MRX-ScreenSaver.command
  3. System Settings → Screen Saver → MRX ScreenSaver → Preview
  4. Turn OFF "Show large clock" if you only see a black screen with system time

Manual install:
  cp -R MRXScreenSaver.saver ~/Library/Screen\ Savers/
  xattr -cr ~/Library/Screen\ Savers/MRXScreenSaver.saver
  codesign --force --deep -s - --timestamp=none ~/Library/Screen\ Savers/MRXScreenSaver.saver

If Preview still fails:
  killall legacyScreenSaver ScreenSaverEngine 2>/dev/null
  sudo rm -rf "/Library/Screen Savers/MRXScreenSaver.saver"

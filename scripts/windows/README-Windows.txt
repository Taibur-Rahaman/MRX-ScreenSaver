MRX ScreenSaver for Windows
===========================

Requires: Windows 10/11 (64-bit) + WebView2 Runtime
  https://developer.microsoft.com/microsoft-edge/webview2/

INSTALL (required steps)
------------------------
1. Unzip MRXScreenSaver-Windows.zip
2. Right-click Install.bat → Run as administrator
   (or double-click — it will ask for Admin; you MUST approve)
3. When the CLASSIC "Screen Saver Settings" window opens:
   - Open the dropdown at the top
   - Select "MRXScreenSaver"
   - Click Apply, then OK

WHERE TO FIND IT
----------------
Third-party screen savers appear ONLY in the classic Control Panel dialog:
  • Win+R → control desk.cpl,,1
  • Or double-click Open-Screen-Saver-Settings.bat

They do NOT appear in:
  • Windows 11 Settings → Personalization → Lock screen → Screen saver
  (that page only shows built-in options like Blank, 3D Text, Photos)

WHY "RUN AS ADMINISTRATOR"?
----------------------------
Windows scans only C:\Windows\System32 for .scr files.
Without admin, the installer cannot copy there and the saver will
never show in the list.

TEST WITHOUT INSTALLING
-----------------------
Double-click MRXScreenSaver.scr (fullscreen test; mouse/key to exit after ~1s)

UNINSTALL
---------
Run Uninstall.bat as administrator.

Download:
https://github.com/Taibur-Rahaman/MRX-ScreenSaver/releases

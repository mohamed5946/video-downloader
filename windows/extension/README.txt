SnapDL — Browser Extension (Edge / Chrome)
==============================================
The extension adds a "Download video" button over videos playing in your
browser (like IDM) and can send browser downloads to the SnapDL app.

IMPORTANT: the SnapDL desktop app must be RUNNING for the extension to work.
The extension talks to the app on your own computer only (127.0.0.1:47811).
Nothing is uploaded anywhere.

INSTALL (free, no Web Store needed)
------------------------------------
EDGE:
  1. Open Edge and go to: edge://extensions
  2. Turn ON "Developer mode" (bottom-left).
  3. Click "Load unpacked".
  4. Select the "extension" folder that came with SnapDL (this folder).
  5. Done — the SnapDL icon appears in the toolbar.

CHROME:
  1. Open Chrome and go to: chrome://extensions
  2. Turn ON "Developer mode" (top-right).
  3. Click "Load unpacked".
  4. Select the "extension" folder that came with SnapDL (this folder).
  5. Done — the SnapDL icon appears in the toolbar.

HOW TO USE
----------
- VIDEO BUTTON: play any video (YouTube, TikTok, Instagram, Facebook, X...)
  and a glass "Download video" button appears on the top-right of the video.
  Click it — the page link is sent to SnapDL and the video downloads there.
  (The button sends the page link, never the video blob — the app downloads
  the real video itself.)
- RIGHT-CLICK: right-click any link, image, video or audio on a page and
  choose "Download with SnapDL".
- POPUP: click the SnapDL icon in the toolbar to check if the app is running,
  send the current page's video, or turn ON "Intercept browser downloads"
  (IDM-style: every browser download goes to SnapDL instead).

TROUBLESHOOTING
---------------
- "SnapDL isn't running": open the SnapDL desktop app first, then try again.
- Button doesn't appear: refresh the page; the video must be playing (or
  have played). Some sites block overlays — use right-click instead.
- If Edge/Chrome disables the extension after a restart, go back to
  edge://extensions (or chrome://extensions) and re-enable it.

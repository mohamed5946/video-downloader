SnapDL — Video Downloader v1.0.0 (Windows)
==========================================

What is SnapDL?
---------------
A free downloader for YouTube, TikTok, Instagram, Facebook and X (Twitter).
Paste a link, pick a quality, and the video is yours. No ads, no accounts.

How to run
----------
1. Unzip this folder anywhere (for example on your Desktop).
2. Double-click SnapDL.exe. (On first run Windows may show SmartScreen —
   click "More info" then "Run anyway".)
3. Paste a video link, click "Get info", pick a quality, click Download.
   Files go to: C:\Users\<you>\Downloads\SnapDL (you can change it in the app).

What is inside this folder?
---------------------------
- SnapDL.exe — the app.
- yt-dlp.exe — the download engine (do not delete).
- ffmpeg.exe / ffprobe.exe — video/audio merging and MP3 conversion (do not delete).
- extension\ — the Edge/Chrome browser extension (see extension\README.txt).
  It adds a "Download video" button over videos in the browser, like IDM.
  The SnapDL app must be running for the button to work.
- snapdl-history.json / snapdl-log.txt — created on first run (history + diagnostics log).

Features
--------
- Qualities: Highest, 4K, 1080p, 720p, Lowest, Audio only (MP3).
- Live progress: percentage, speed and ETA while downloading.
- Pause / Resume: pausing keeps the partial file and resumes from the same
  point — it never restarts from zero.
- History: every download is listed with Open / Download again / Delete.
- Updates: the "Check for updates" button in the app checks for a new version.
- Diagnostics log: if anything fails, the exact reason is in the in-app log.

Notes
-----
- You need internet for downloads.
- Some videos may be unavailable for download (private, age-restricted or
  removed videos). The log will say why.
- Downloading is for your personal use — respect creators' rights.
- Developer: Mohamed El Sayed — https://mohamed5946.github.io/portfolio/

# Building the Windows app (SnapDL)

## Requirements

- Node.js 20+ and npm
- Windows (for packaging; the app itself also runs from source with Electron)

## Steps

```bat
cd windows
npm install
npm run fetch-tools
npm run package-win
```

The packaged app appears in `../dist/SnapDL-win32-x64/`.

## Required helper binaries

Before packaging, fetch the download tool — do not copy binaries in by hand:

```bat
npm run fetch-tools
```

This runs `scripts/fetch-ytdlp.js`, which downloads yt-dlp.exe **2026.10.26**
from the yt-dlp GitHub release, verifies its SHA-256 checksum against the
release's `SHA2-256SUMS`, and places it in `windows/bin/` (created if needed).
The app also updates yt-dlp itself from inside the app (first run, then
weekly, and once after a failed video-info fetch), falling back to the
bundled copy when the update fails.

Still place these files next to `main.js` (in this folder) by hand:

- `ffmpeg.exe` and `ffprobe.exe` — https://www.gyan.dev/ffmpeg/builds/
  (ffmpeg essentials build)

`yt-dlp.exe` and `ffmpeg.exe` are fetched, not committed to this repo
(large binaries — `*.exe` is in the repo-root `.gitignore`, so
`windows/bin/` never gets committed). Run `npm run fetch-tools` again
before packaging whenever the bundled tool version changes.

## Run from source

```bat
npm install
npm start
```

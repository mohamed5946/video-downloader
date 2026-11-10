# Building the Windows app (SnapDL)

## Requirements

- Node.js 20+ and npm
- Windows (for packaging; the app itself also runs from source with Electron)

## Steps

```bat
cd windows
npm install
npm run package-win
```

The packaged app appears in `../dist/SnapDL-win32-x64/`.

## Required helper binaries

Before packaging, place these files next to `main.js` (in this folder):

- `yt-dlp.exe` — https://github.com/yt-dlp/yt-dlp/releases
- `ffmpeg.exe` and `ffprobe.exe` — https://www.gyan.dev/ffmpeg/builds/
  (ffmpeg essentials build)

They are not committed to this repo (large binaries).

## Run from source

```bat
npm install
npm start
```

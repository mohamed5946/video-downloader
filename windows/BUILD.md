# Building the Windows app (SnapDL)

## Requirements

- Node.js 20+ and npm
- Windows (for packaging; the app itself also runs from source with Electron)

## The installer (v1.0.8+, the release build)

The release build is a real NSIS Setup installer, built with
electron-builder (config in `electron-builder.yml`):

```bat
cd windows
npm install
npm run fetch-tools
npm run fetch-ffmpeg
npm run package-installer
```

This produces in `../dist/`:

- `SnapDL Setup 1.0.8.exe` — guided installer: install-directory
  choice, Start menu entry, desktop shortcut, and an uninstall entry
  in Windows Settings / Control Panel.
- `latest.yml` (+ `SnapDL Setup 1.0.8.exe.blockmap`) — published with
  the GitHub release so the installed app can update itself
  differentially through electron-updater (wired in `main.js`).

Future updates arrive inside the installed app: Settings → Updates
(or the automatic check on launch) asks electron-updater, which
downloads only the changed blocks and installs on restart. The old
ZIP-based update path is kept only as a fallback for portable /
from-source runs.

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

ffmpeg comes from the gyan.dev essentials build:

```bat
npm run fetch-ffmpeg
```

This runs `scripts/fetch-ffmpeg.js`, which downloads
`ffmpeg-release-essentials.zip`, verifies it extracts cleanly, and places
`ffmpeg.exe` + `ffprobe.exe` in `windows/bin/`.

`yt-dlp.exe` and `ffmpeg.exe` are fetched, not committed to this repo
(large binaries — `*.exe` is in the repo-root `.gitignore`, so
`windows/bin/` never gets committed). Run both fetch scripts again
before packaging whenever a bundled tool version changes.

## Legacy ZIP build (electron-packager, no installer)

```bat
cd windows
npm install
npm run fetch-tools
npm run fetch-ffmpeg
npm run package-win
```

The packaged app appears in `../dist/SnapDL-win32-x64/`. The helper
binaries from `windows/bin/` must be copied next to `SnapDL.exe`
(the old script never bundled them automatically).

## Run from source

```bat
npm install
npm start
```

From-source runs on Linux (for UI previews) use the Linux Electron
binary downloaded by `npm install`; the Windows-only helpers are
simply absent there. Run with `--no-sandbox` when running as root.

'use strict';
/**
 * fetch-ffmpeg.js — plain Node script (no Electron).
 *
 * Downloads the ffmpeg essentials build (ffmpeg-release-essentials.zip)
 * from gyan.dev, extracts ffmpeg.exe + ffprobe.exe, and places them in
 * windows/bin/ (created if needed). Uses the system unzip tool when
 * available (PowerShell Expand-Archive on Windows, `unzip` elsewhere).
 *
 * Run:  npm run fetch-ffmpeg   (from the windows/ folder)
 *
 * The binaries are NOT committed to the repo: windows/bin/*.exe is
 * covered by the `*.exe` rule in the repo-root .gitignore.
 */
const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');

const ZIP_URL = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip';
const binDir = path.join(__dirname, '..', 'bin');
const zipPath = path.join(binDir, '.ffmpeg-essentials.zip');
const extractDir = path.join(binDir, '.ffmpeg-extract');

function downloadToFile(url, destPath) {
  return (async () => {
    const res = await fetch(url, { redirect: 'follow' });
    if (!res.ok) throw new Error(`Download failed: ${url} answered HTTP ${res.status}`);
    const stream = fs.createWriteStream(destPath);
    const reader = res.body.getReader();
    while (true) {
      const done = await reader.read().then(r => { if (!r.done) stream.write(Buffer.from(r.value)); return r.done; });
      if (done) break;
    }
    await new Promise((resolve, reject) => { stream.end(err => err ? reject(err) : resolve()); });
  })();
}

function run(cmd, args) {
  return new Promise((resolve, reject) => {
    execFile(cmd, args, (err, stdout, stderr) => {
      if (err) return reject(new Error(`${cmd} failed: ${stderr || err.message}`));
      resolve(stdout);
    });
  });
}

async function main() {
  console.log('Fetching ffmpeg essentials build ...');
  fs.mkdirSync(binDir, { recursive: true });
  fs.rmSync(extractDir, { recursive: true, force: true });
  await downloadToFile(ZIP_URL, zipPath);
  console.log('Downloaded, extracting ...');
  if (process.platform === 'win32') {
    await run('powershell', ['-NoProfile', '-Command', `Expand-Archive -Force '${zipPath}' -DestinationPath '${extractDir}'`]);
  } else {
    await run('unzip', ['-q', '-o', zipPath, '-d', extractDir]);
  }
  const found = {};
  const walk = (dir) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) walk(p);
      else if (e.name === 'ffmpeg.exe' || e.name === 'ffprobe.exe') found[e.name] = p;
    }
  };
  walk(extractDir);
  for (const name of ['ffmpeg.exe', 'ffprobe.exe']) {
    if (!found[name]) throw new Error(`${name} not found in the essentials zip`);
    fs.copyFileSync(found[name], path.join(binDir, name));
    console.log(`Placed ${name} in windows/bin/`);
  }
  fs.rmSync(zipPath, { force: true });
  fs.rmSync(extractDir, { recursive: true, force: true });
  console.log('ffmpeg fetch done.');
}

main().catch((e) => { console.error(e.message); process.exit(1); });

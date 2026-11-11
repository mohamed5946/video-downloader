'use strict';
/**
 * fetch-ytdlp.js — plain Node script (no Electron).
 *
 * Downloads yt-dlp.exe 2026.10.26 + SHA2-256SUMS from the yt-dlp GitHub
 * release, verifies the SHA-256 checksum, and places yt-dlp.exe into
 * windows/bin/ (created if needed).
 *
 * Run:  npm run fetch-tools   (from the windows/ folder)
 *
 * The binary is NOT committed to the repo: windows/bin/*.exe is covered
 * by the `*.exe` rule in the repo-root .gitignore. Run this script again
 * before packaging whenever the bundled tool version changes.
 */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const VERSION = '2026.10.26';
const BASE_URL = `https://github.com/yt-dlp/yt-dlp/releases/download/${VERSION}`;
const EXE_URL = `${BASE_URL}/yt-dlp.exe`;
const SUMS_URL = `${BASE_URL}/SHA2-256SUMS`;

const binDir = path.join(__dirname, '..', 'bin');
const targetPath = path.join(binDir, 'yt-dlp.exe');
const tmpPath = path.join(binDir, `.yt-dlp.exe.tmp-${process.pid}`);

async function downloadToFile(url, destPath) {
  const res = await fetch(url, { redirect: 'follow' });
  if (!res.ok) throw new Error(`Download failed: ${url} answered HTTP ${res.status}`);
  const stream = fs.createWriteStream(destPath);
  const reader = res.body.getReader();
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    stream.write(Buffer.from(value));
  }
  await new Promise((resolve, reject) => { stream.end(err => err ? reject(err) : resolve()); });
}

function sha256File(filePath) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash('sha256');
    const stream = fs.createReadStream(filePath);
    stream.on('data', d => hash.update(d));
    stream.on('error', reject);
    stream.on('end', () => resolve(hash.digest('hex')));
  });
}

async function main() {
  console.log(`Fetching yt-dlp ${VERSION} ...`);
  fs.mkdirSync(binDir, { recursive: true });
  try {
    await downloadToFile(EXE_URL, tmpPath);
    console.log('Downloaded yt-dlp.exe, fetching SHA2-256SUMS ...');
    const sumsRes = await fetch(SUMS_URL, { redirect: 'follow' });
    if (!sumsRes.ok) throw new Error(`SHA2-256SUMS answered HTTP ${sumsRes.status}`);
    const sumsText = await sumsRes.text();
    let expected = '';
    for (const line of sumsText.split(/\r?\n/)) {
      const parts = line.trim().split(/\s+/);
      if (parts.length >= 2 && parts[1].replace(/^\*/, '') === 'yt-dlp.exe') { expected = parts[0].toLowerCase(); break; }
    }
    if (!expected) throw new Error('Checksum not found for yt-dlp.exe in SHA2-256SUMS');
    const actual = await sha256File(tmpPath);
    if (actual !== expected) throw new Error(`SHA-256 mismatch for yt-dlp.exe (expected ${expected}, got ${actual})`);
    console.log('SHA-256 verified.');
    fs.renameSync(tmpPath, targetPath);
    console.log(`yt-dlp ${VERSION} installed to ${targetPath}`);
  } catch (e) {
    try { if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath); } catch (_) {}
    console.error('fetch-ytdlp failed: ' + e.message);
    process.exit(1);
  }
}

main();

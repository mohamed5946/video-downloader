'use strict';
/**
 * SnapDL — video downloader (YouTube, TikTok, Instagram, Facebook, X)
 * Main process. Engine: bundled yt-dlp.exe + ffmpeg.exe (Windows).
 * Local server on 127.0.0.1:47811 serves the browser extension.
 */
const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');
const path = require('path');
const fs = require('fs');
const { spawn, execFile } = require('child_process');
const http = require('http');

const APP_NAME = 'SnapDL';
const APP_VERSION = '1.0.0';
const UPDATE_MANIFEST_URL = 'https://github.com/mohamed5946/video-downloader/releases/latest/download/update.json';
const RELEASES_URL = 'https://github.com/mohamed5946/video-downloader/releases/latest';
const PORTFOLIO_URL = 'https://mohamed5946.github.io/portfolio/';
const PREVIEW_MODE = process.argv.includes('--preview');
// Preview-only: the sandbox MITMs TLS, so YouTube's cert fails here.
// On Mohamed's laptop this switch is NOT set — real certs are enforced.
if (PREVIEW_MODE) app.commandLine.appendSwitch('ignore-certificate-errors');
const LOCAL_PORT = 47811; // local server the browser extension talks to (127.0.0.1 only)

const PLATFORM_NAMES = {
  youtube: 'YouTube', tiktok: 'TikTok', instagram: 'Instagram',
  facebook: 'Facebook', twitter: 'X (Twitter)', x: 'X (Twitter)'
};

let win = null;

// ---------------------------------------------------------------- paths
function exeDir() { return path.dirname(process.execPath); }

function dataDir() {
  // Portable: keep history + logs next to the app when packaged.
  if (app.isPackaged) {
    const dir = exeDir();
    try { fs.accessSync(dir, fs.constants.W_OK); return dir; } catch (_) { /* fall through */ }
  }
  return app.getPath('userData');
}
function dataFile(name) { return path.join(dataDir(), name); }
function settingsPath() { return dataFile('snapdl-settings.json'); }
function historyPath() { return dataFile('snapdl-history.json'); }
function logPath() { return dataFile('snapdl-log.txt'); }

// ---------------------------------------------------------------- logging
const logEntries = [];
function log(category, message, level = 'info') {
  const entry = { time: new Date().toISOString(), category, level, message };
  logEntries.push(entry);
  if (logEntries.length > 500) logEntries.shift();
  try { fs.appendFileSync(logPath(), `[${entry.time}] [${category}] [${level.toUpperCase()}] ${message}\n`); } catch (_) {}
  if (win && !win.isDestroyed()) win.webContents.send('log-added', entry);
}

// User-facing strings from the main process, in the UI language.
// (Diagnostics log lines stay in English — they are technical records.)
const MAIN_STR = {
  en: {
    ytdlpMissing: 'A required program file is missing. Reinstall SnapDL.',
    invalidLink: 'Paste a valid link starting with http:// or https://',
    infoTimeout: 'Timed out while fetching video info. Check your connection and try again.',
    infoFailed: 'Could not read this link.',
    wifiOnly: 'Wi-Fi only is ON and you are not connected to Wi-Fi. Turn it off in Settings → Downloads, or connect to Wi-Fi.',
    folderFail: 'Could not create the download folder: ',
    noPause: 'No active download to pause.',
    noResume: 'No paused download to resume.',
    noJob: 'No such download.',
    entryNotFound: 'Entry not found.',
    fileGone: 'File no longer exists on disk.',
    extMissing: 'Extension folder not found. Reinstall SnapDL.',
    manifestInvalid: 'The update manifest is invalid.',
    updateHttp: 'Update server answered HTTP ',
    updateHttpSuffix: '. Try again later.',
    updateUnreachable: 'Could not reach the update server. Check your connection and try again.',
    urlRequired: 'A valid http(s) URL is required.',
    ytdlpNotFound: 'A required program file is missing',
    unknownSetting: 'Unknown setting: '
  },
  ar: {
    ytdlpMissing: 'ملف من ملفات البرنامج غير موجود. أعد تثبيت SnapDL.',
    invalidLink: 'الصق رابطًا صحيحًا يبدأ بـ http:// أو https://',
    infoTimeout: 'انتهت المهلة أثناء جلب معلومات الفيديو. تحقق من اتصالك وحاول مرة أخرى.',
    infoFailed: 'تعذّر قراءة هذا الرابط.',
    wifiOnly: 'خيار "واي فاي فقط" مفعّل ولست متصلًا بشبكة واي فاي. أوقفه من الإعدادات ← التنزيلات، أو اتصل بشبكة واي فاي.',
    folderFail: 'تعذّر إنشاء مجلد التنزيل: ',
    noPause: 'لا يوجد تنزيل نشط لإيقافه مؤقتًا.',
    noResume: 'لا يوجد تنزيل متوقف لاستئنافه.',
    noJob: 'لا يوجد مثل هذا التنزيل.',
    entryNotFound: 'العنصر غير موجود.',
    fileGone: 'الملف لم يعد موجودًا على القرص.',
    extMissing: 'مجلد الإضافة غير موجود. أعد تثبيت SnapDL.',
    manifestInvalid: 'ملف التحديث غير صالح.',
    updateHttp: 'خادم التحديث ردّ بالرمز ',
    updateHttpSuffix: '. حاول مرة أخرى لاحقًا.',
    updateUnreachable: 'تعذّر الوصول إلى خادم التحديث. تحقق من اتصالك وحاول مرة أخرى.',
    urlRequired: 'مطلوب رابط http(s) صحيح.',
    ytdlpNotFound: 'ملف من ملفات البرنامج غير موجود',
    unknownSetting: 'إعداد غير معروف: '
  }
};
function uiLang() { try { return (loadSettings().language === 'en') ? 'en' : 'ar'; } catch (_) { return 'ar'; } }
function ms(key) { const l = uiLang(); return (MAIN_STR[l] && MAIN_STR[l][key]) || MAIN_STR.en[key] || key; }

// ---------------------------------------------------------------- settings
const DEFAULT_SETTINGS = {
  theme: 'light',           // dark | light | system
  language: 'ar',           // ar | en
  defaultQuality: 'highest',
  wifiOnly: false,
  maxConcurrent: 1,         // 1 | 2 | 3
  adblock: true,
  adblockBlocked: 0,
  autoCheck: false,
  downloadDir: null,
  extLastSeen: 0,
  extVersion: ''
};
function loadSettings() {
  let s = {};
  try { s = JSON.parse(fs.readFileSync(settingsPath(), 'utf8')) || {}; } catch (_) {}
  return Object.assign({}, DEFAULT_SETTINGS, s);
}
function saveSettings(s) {
  try { fs.writeFileSync(settingsPath(), JSON.stringify(s, null, 2)); } catch (e) { log('SYSTEM', 'Could not save settings: ' + e.message, 'error'); }
}
function getDownloadDir() {
  if (PREVIEW_MODE) return 'C:\\Users\\DELL\\Downloads\\SnapDL'; // previews look like the real Windows app
  const s = loadSettings();
  return s.downloadDir || path.join(app.getPath('downloads'), 'SnapDL');
}

// ---------------------------------------------------------------- history
let history = [];
function loadHistory() {
  try { history = JSON.parse(fs.readFileSync(historyPath(), 'utf8')) || []; } catch (_) { history = []; }
  if (!Array.isArray(history)) history = [];
}
function saveHistory() {
  try { fs.writeFileSync(historyPath(), JSON.stringify(history, null, 2)); } catch (e) { log('HISTORY', 'Could not save history: ' + e.message, 'error'); }
}
function addHistory(entry) {
  history.unshift(entry);
  if (history.length > 200) history = history.slice(0, 200);
  saveHistory();
  sendHistory();
}
function sendHistory() {
  if (win && !win.isDestroyed()) win.webContents.send('history-updated', history);
}

// ---------------------------------------------------------------- binaries
function resolveBin(name) {
  const candidates = [
    path.join(exeDir(), name),
    path.join(process.resourcesPath, 'app', 'bin', name),
    path.join(app.getAppPath(), 'bin', name),
    path.join(__dirname, 'bin', name),
    path.join(__dirname, '..', 'bin', name)
  ];
  for (const c of candidates) { try { if (fs.existsSync(c)) return c; } catch (_) {} }
  return null;
}
function ytdlpPath() { return resolveBin('yt-dlp.exe'); }
function ffmpegDir() {
  const ff = resolveBin('ffmpeg.exe');
  return ff ? path.dirname(ff) : null;
}
function humanSize(bytes) {
  if (bytes == null || isNaN(bytes)) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let i = 0; let n = bytes;
  while (n >= 1024 && i < units.length - 1) { n /= 1024; i++; }
  return (n >= 100 ? Math.round(n) : n.toFixed(1)) + ' ' + units[i];
}
function platformOf(info) {
  const key = (info && info.extractor_key) ? String(info.extractor_key).toLowerCase() : '';
  for (const k of Object.keys(PLATFORM_NAMES)) if (key.includes(k)) return PLATFORM_NAMES[k];
  return info && info.extractor ? info.extractor : 'Video';
}
function maxHeightOf(info) {
  let max = 0;
  (info.formats || []).forEach(f => { if (f.height && f.height > max) max = f.height; });
  return max;
}

// ---------------------------------------------------------------- downloads
const QUALITY_FORMATS = {
  highest: { label: 'Highest quality', args: ['-f', 'bv*+ba/b'] },
  '4k':    { label: '4K (2160p)',      args: ['-f', 'bv*[height<=2160]+ba/b[height<=2160]'] },
  '1080p': { label: '1080p Full HD',  args: ['-f', 'bv*[height<=1080]+ba/b[height<=1080]'] },
  '720p':  { label: '720p HD',         args: ['-f', 'bv*[height<=720]+ba/b[height<=720]'] },
  lowest:  { label: 'Lowest quality',  args: ['-f', 'wv*+wa/w'] },
  audio:   { label: 'Audio only (MP3)', args: ['-f', 'ba', '-x', '--audio-format', 'mp3', '--audio-quality', '0'] }
};
const FILE_EXT_RE = /\.(exe|msi|zip|rar|7z|pdf|jpg|jpeg|png|gif|webp|mp3|mp4|mkv|mov|apk|dmg|iso|doc|docx|xls|xlsx|ppt|pptx|txt|csv)$/i;

// Job queue: up to maxConcurrent active downloads, the rest wait in line.
const jobs = new Map(); // id -> active job
const queue = [];       // job objects waiting for a slot
let jobSeq = 0;

function stripJob(job) {
  const { child, _controller, ...pub } = job;
  return pub;
}
function sendJobList() {
  if (!win || win.isDestroyed()) return;
  const list = [...jobs.values(), ...queue].map(stripJob);
  win.webContents.send('download-list', list);
}
function activeDownloadCount() {
  let n = 0;
  for (const j of jobs.values()) if (j.status === 'downloading' || j.status === 'starting') n++;
  return n;
}
function pumpQueue() {
  const max = Math.max(1, Math.min(3, loadSettings().maxConcurrent || 1));
  while (activeDownloadCount() < max && queue.length) {
    const job = queue.shift();
    jobs.set(job.id, job);
    if (job.kind === 'file') runFileDownload(job); else spawnDownload(job);
  }
  sendJobList();
}

function baseYtdlpArgs(url, outDir, qualityKey) {
  const q = QUALITY_FORMATS[qualityKey] || QUALITY_FORMATS.highest;
  const args = ['--no-playlist', '--newline', '--no-warnings', '--continue'];
  const ff = ffmpegDir();
  if (ff) args.push('--ffmpeg-location', ff);
  args.push(...q.args);
  if (qualityKey !== 'audio') args.push('--merge-output-format', 'mp4');
  args.push('-o', path.join(outDir, '%(title)s [%(id)s].%(ext)s'));
  args.push(url);
  return args;
}

function killChild(child) {
  if (!child || child.killed) return;
  if (process.platform === 'win32') {
    execFile('taskkill', ['/PID', String(child.pid), '/F', '/T'], () => {});
  } else {
    try { child.kill('SIGKILL'); } catch (_) {}
  }
}

function finishJob(job) {
  jobs.delete(job.id);
  pumpQueue();
}

// Strip internal tool names from any text shown to the user (log viewer / toasts).
function scrubEngineWords(s) { return String(s || '').replace(/yt-dlp/gi, '').replace(/ffmpeg/gi, ''); }

function spawnDownload(job) {
  const exe = ytdlpPath();
  if (!exe) {
    log('DOWNLOAD', 'A required program file is missing. Reinstall SnapDL.', 'error');
    job.status = 'error';
    job.error = ms('ytdlpNotFound');
    sendJobList();
    finishJob(job);
    return;
  }
  const args = baseYtdlpArgs(job.url, job.outDir, job.quality);
  log('DOWNLOAD', `Starting download: ${job.url} (quality: ${job.quality})`);
  const child = spawn(exe, args, { windowsHide: true });
  job.child = child;
  job.status = 'downloading';
  job.progress = job.progress || 0;
  job.speed = ''; job.eta = '';
  sendJobList();

  let stderrBuf = '';
  child.stdout.on('data', d => {
    const text = d.toString();
    for (const line of text.split(/\r?\n/)) {
      if (!line) continue;
      const m = line.match(/\[download\]\s+(\d+(?:\.\d+)?)% of\s+([\d.]+\s*\w+)\s+at\s+([\d.]+\s*\w+\/s)\s+ETA\s+([\d:]+)/);
      if (m) {
        job.progress = parseFloat(m[1]);
        job.sizeTotal = m[2].trim();
        job.speed = m[3].trim();
        job.eta = m[4].trim();
        job.phase = 'downloading';
        sendJobList();
        continue;
      }
      if (/\[download\]\s+100%/.test(line)) { job.progress = 100; job.phase = 'finishing'; sendJobList(); continue; }
      if (/^\[Merger\]/.test(line)) { job.phase = 'merging'; sendJobList(); continue; }
      if (/^\[ExtractAudio\]/.test(line)) { job.phase = 'converting'; sendJobList(); continue; }
      if (/^\[VideoConvertor\]/.test(line)) { job.phase = 'converting'; sendJobList(); continue; }
      const dest = line.match(/\[download\] Destination:\s+(.+)$/);
      if (dest) { job.outFile = dest[1].trim(); }
      const already = line.match(/\[download\]\s+(.+?)\s+has already been downloaded/);
      if (already) { job.outFile = already[1].trim(); }
    }
  });
  child.stderr.on('data', d => { stderrBuf += d.toString(); });
  child.on('error', err => {
    log('DOWNLOAD', 'Failed to start the download: ' + scrubEngineWords(err.message), 'error');
    job.status = 'error'; job.error = ms('ytdlpNotFound');
    sendJobList();
    finishJob(job);
  });
  child.on('close', (code, signal) => {
    job.child = null;
    if (job.status === 'paused' || job.status === 'cancelled') return; // handled by pause/cancel
    if (code === 0) {
      job.status = 'done'; job.progress = 100; job.speed = ''; job.eta = '';
      let size = null;
      if (job.outFile) { try { size = fs.statSync(job.outFile).size; } catch (_) {} }
      log('DOWNLOAD', `Finished: ${job.title || job.url} (${humanSize(size)})`);
      addHistory({
        id: job.id, title: job.title || job.url, platform: job.platform || 'Video',
        quality: job.quality,
        url: job.url, path: job.outFile || '', size, date: new Date().toISOString(), status: 'done'
      });
    } else {
      const reason = scrubEngineWords(stderrBuf.trim().split('\n').slice(-3).join(' ') || `Download failed with code ${code}`).slice(0, 300);
      job.status = 'error'; job.error = reason;
      log('DOWNLOAD', `Download failed (${job.url}): ${reason}`, 'error');
    }
    sendJobList();
    finishJob(job);
  });
}

function findPartFile(job) {
  try {
    const files = fs.readdirSync(job.outDir);
    return files.filter(f => f.endsWith('.part') || f.endsWith('.part-Frag')).map(f => path.join(job.outDir, f));
  } catch (_) { return []; }
}

// ---------------------------------------------------------------- direct file downloads (browser extension)
function fileNameFromUrl(url) {
  try {
    const u = new URL(url);
    let base = decodeURIComponent(u.pathname.split('/').filter(Boolean).pop() || 'download');
    base = base.replace(/[<>:"/\\|?*\x00-\x1f]/g, '_').slice(0, 120);
    return base || 'download';
  } catch (_) { return 'download'; }
}

// Stream a direct file URL to disk with real pause (abort) + resume (HTTP Range).
async function runFileDownload(job) {
  const target = path.join(job.outDir, job.fileName);
  job.outFile = target;
  let downloaded = 0;
  try { if (fs.existsSync(target)) downloaded = fs.statSync(target).size; } catch (_) {}
  const headers = {};
  if (downloaded > 0) headers['Range'] = `bytes=${downloaded}-`;
  const ctrl = new AbortController();
  job._controller = ctrl;
  job.status = 'downloading';
  job.phase = 'downloading';
  job.progress = 0; job.speed = ''; job.eta = '';
  log('DOWNLOAD', `Starting file download: ${job.url} (${downloaded > 0 ? 'resuming at ' + humanSize(downloaded) : 'fresh'})`);
  sendJobList();
  const startedAt = Date.now();
  let lastBytes = downloaded, lastTime = startedAt;
  try {
    const res = await fetch(job.url, { headers, signal: ctrl.signal, redirect: 'follow' });
    if (!res.ok && res.status !== 206) throw new Error(`Server answered HTTP ${res.status}`);
    const total = (res.status === 206 && downloaded > 0)
      ? downloaded + Number(res.headers.get('content-length') || 0)
      : Number(res.headers.get('content-length') || 0);
    job.sizeTotal = total ? humanSize(total) : '—';
    job.downloaded = downloaded;
    if (total) job.progress = (downloaded / total) * 100;
    const flags = (downloaded > 0 && res.status === 206) ? 'a' : 'w';
    if (flags === 'w') job.downloaded = 0;
    const stream = fs.createWriteStream(target, { flags });
    const reader = res.body.getReader();
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (job.status !== 'downloading') { try { await reader.cancel(); } catch (_) {} break; }
      stream.write(Buffer.from(value));
      job.downloaded += value.length;
      const now = Date.now();
      const dt = (now - lastTime) / 1000;
      if (dt >= 0.5) {
        const bps = (job.downloaded - lastBytes) / dt;
        job.speed = humanSize(bps) + '/s';
        if (total && bps > 0) {
          const secs = Math.round((total - job.downloaded) / bps);
          job.eta = `${String(Math.floor(secs / 60)).padStart(2, '0')}:${String(secs % 60).padStart(2, '0')}`;
        }
        if (total) job.progress = (job.downloaded / total) * 100;
        lastBytes = job.downloaded; lastTime = now;
        sendJobList();
      }
    }
    await new Promise(r => stream.end(r));
    job._controller = null;
    if (job.status === 'paused' || job.status === 'cancelled') return; // pause/cancel owns the state
    job.status = 'done'; job.progress = 100; job.speed = ''; job.eta = '';
    let size = null;
    try { size = fs.statSync(target).size; } catch (_) {}
    log('DOWNLOAD', `Finished: ${job.title} (${humanSize(size)})`);
    addHistory({
      id: job.id, title: job.title, platform: 'File', quality: 'file',
      url: job.url, path: target, size, date: new Date().toISOString(), status: 'done'
    });
    sendJobList();
    finishJob(job);
  } catch (e) {
    job._controller = null;
    if (job.status === 'paused' || job.status === 'cancelled') return;
    if (e && e.name === 'AbortError') return;
    job.status = 'error';
    job.error = (e.message || 'Download failed').slice(0, 300);
    log('DOWNLOAD', `File download failed (${job.url}): ${job.error}`, 'error');
    sendJobList();
    finishJob(job);
  }
}

// Wi-Fi-only: on Windows, check the active Wi-Fi connection (netsh).
async function isOnWifi() {
  if (process.platform !== 'win32') return true; // dev machines: assume OK
  return new Promise(resolve => {
    execFile('netsh', ['wlan', 'show', 'interfaces'], (err, stdout) => {
      if (err) return resolve(true); // fail open, and log it
      resolve(/State\s*:\s*connected/i.test(String(stdout)));
    });
  });
}

async function startJob({ url, quality, kind }) {
  const settings = loadSettings();
  if (settings.wifiOnly) {
    const onWifi = await isOnWifi();
    if (!onWifi) {
      log('DOWNLOAD', 'Wi-Fi only is ON and no Wi-Fi connection was found — download refused.', 'error');
      return { ok: false, error: ms('wifiOnly') };
    }
  }
  const outDir = getDownloadDir();
  try { fs.mkdirSync(outDir, { recursive: true }); } catch (e) {
    log('DOWNLOAD', 'Could not create download folder: ' + e.message, 'error');
    return { ok: false, error: ms('folderFail') + outDir };
  }
  const isFile = kind === 'file' || (kind !== 'video' && FILE_EXT_RE.test(url));
  const job = {
    id: ++jobSeq, url, quality: quality || settings.defaultQuality || 'highest', outDir,
    kind: isFile ? 'file' : 'video',
    status: 'starting', progress: 0, speed: '', eta: '', phase: 'starting',
    title: '', platform: '', outFile: ''
  };
  if (isFile) {
    job.fileName = fileNameFromUrl(url);
    job.title = job.fileName;
    job.platform = 'File';
  }
  const max = Math.max(1, Math.min(3, settings.maxConcurrent || 1));
  if (activeDownloadCount() >= max) {
    job.status = 'queued';
    queue.push(job);
    log('DOWNLOAD', `Queued (slot busy, max ${max} simultaneous): ${url}`);
    sendJobList();
    return { ok: true, jobId: job.id, queued: true };
  }
  jobs.set(job.id, job);
  if (isFile) runFileDownload(job); else spawnDownload(job);
  return { ok: true, jobId: job.id };
}

function pauseJob(jobId) {
  const job = jobs.get(jobId);
  if (!job || (job.status !== 'downloading' && job.status !== 'starting')) return { ok: false, error: ms('noPause') };
  if (job.kind === 'file') {
    log('DOWNLOAD', `Paused at ${Math.round(job.progress || 0)}% — partial file kept for resume.`);
    job.status = 'paused';
    if (job._controller) { try { job._controller.abort(); } catch (_) {} }
    sendJobList();
    return { ok: true };
  }
  if (!job.child) return { ok: false, error: 'No active download to pause.' };
  log('DOWNLOAD', `Paused at ${Math.round(job.progress || 0)}% — .part file kept for resume.`);
  job.status = 'paused';
  const child = job.child;
  job.child = null;
  killChild(child);
  sendJobList();
  return { ok: true };
}

function resumeJob(jobId) {
  const job = jobs.get(jobId);
  if (!job || job.status !== 'paused') return { ok: false, error: ms('noResume') };
  log('DOWNLOAD', `Resuming from ${Math.round(job.progress || 0)}%.`);
  if (job.kind === 'file') { runFileDownload(job); return { ok: true }; }
  spawnDownload(job); // --continue resumes the existing .part file
  return { ok: true };
}

function cancelJob(jobId) {
  const qi = queue.findIndex(j => j.id === jobId);
  if (qi !== -1) {
    queue.splice(qi, 1);
    log('DOWNLOAD', 'Queued download cancelled by user.');
    sendJobList();
    return { ok: true };
  }
  const job = jobs.get(jobId);
  if (!job) return { ok: false, error: ms('noJob') };
  if (job.kind === 'file') {
    if (job._controller) { try { job._controller.abort(); } catch (_) {} }
    job.status = 'cancelled';
    log('DOWNLOAD', 'Download cancelled by user.');
    if (job.outFile) { try { if (fs.existsSync(job.outFile)) fs.unlinkSync(job.outFile); } catch (_) {} }
    jobs.delete(job.id);
    pumpQueue();
    return { ok: true };
  }
  const parts = findPartFile(job);
  if (job.child) { const child = job.child; job.child = null; killChild(child); }
  job.status = 'cancelled';
  log('DOWNLOAD', 'Download cancelled by user.');
  parts.forEach(p => { try { fs.unlinkSync(p); } catch (_) {} });
  if (job.outFile) { try { if (fs.existsSync(job.outFile)) fs.unlinkSync(job.outFile); } catch (_) {} }
  jobs.delete(job.id);
  pumpQueue();
  return { ok: true };
}

// ---------------------------------------------------------------- window
function createWindow() {
  win = new BrowserWindow({
    width: 1180, height: 780,
    minWidth: 940, minHeight: 620,
    backgroundColor: '#f7f4e9',
    title: APP_NAME,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      webviewTag: true
    }
  });
  win.loadFile(path.join(__dirname, 'src', 'index.html'));
  win.on('closed', () => { win = null; });
}

// ---------------------------------------------------------------- IPC
ipcMain.handle('app-info', () => {
  const s = loadSettings();
  return {
    name: APP_NAME, version: APP_VERSION,
    portfolioUrl: PORTFOLIO_URL, releasesUrl: RELEASES_URL,
    downloadDir: getDownloadDir(),
    adblock: s.adblock !== false, adblockBlocked: s.adblockBlocked || 0
  };
});

ipcMain.handle('get-settings', () => loadSettings());
ipcMain.handle('set-setting', (_e, { key, value }) => {
  if (!Object.prototype.hasOwnProperty.call(DEFAULT_SETTINGS, key)) return { ok: false, error: ms('unknownSetting') + key };
  const s = loadSettings();
  s[key] = value;
  saveSettings(s);
  log('SYSTEM', `Setting changed: ${key} = ${JSON.stringify(value)}`);
  if (win && !win.isDestroyed()) win.webContents.send('settings-changed', { key, value });
  if (key === 'maxConcurrent') pumpQueue();
  return { ok: true };
});
ipcMain.handle('get-adblock-state', () => {
  const s = loadSettings();
  const extConnected = !!(s.extLastSeen && (Date.now() - s.extLastSeen < 120000));
  return { enabled: s.adblock !== false, blocked: s.adblockBlocked || 0, extensionConnected: extConnected, extVersion: s.extVersion || '' };
});

ipcMain.handle('choose-folder', async () => {
  const res = await dialog.showOpenDialog(win, { properties: ['openDirectory'], defaultPath: getDownloadDir() });
  if (res.canceled || !res.filePaths[0]) return null;
  const s = loadSettings(); s.downloadDir = res.filePaths[0]; saveSettings(s);
  log('SYSTEM', 'Download folder set to ' + res.filePaths[0]);
  return res.filePaths[0];
});

ipcMain.handle('fetch-info', async (_e, url) => {
  const exe = ytdlpPath();
  if (!exe) return { ok: false, error: ms('ytdlpMissing') };
  if (!url || !/^https?:\/\//i.test(url)) return { ok: false, error: ms('invalidLink') };
  log('INFO', 'Reading video info: ' + url);
  return await new Promise(resolve => {
    const child = spawn(exe, ['-J', '--no-playlist', '--no-warnings', url], { windowsHide: true });
    let out = '', errBuf = '';
    const timer = setTimeout(() => { try { child.kill('SIGKILL'); } catch (_) {} resolve({ ok: false, error: ms('infoTimeout') }); }, 90000);
    child.stdout.on('data', d => { out += d.toString(); });
    child.stderr.on('data', d => { errBuf += d.toString(); });
    child.on('error', e => { clearTimeout(timer); log('INFO', 'video-info failed to start: ' + scrubEngineWords(e.message), 'error'); resolve({ ok: false, error: ms('infoFailed') }); });
    child.on('close', code => {
      clearTimeout(timer);
      if (code !== 0) {
        const reason = scrubEngineWords(errBuf.trim().split('\n').filter(l => l.trim() && !l.includes('WARNING')).slice(-2).join(' ') || 'Could not read this link.').slice(0, 300);
        log('INFO', 'video-info failed: ' + reason, 'error');
        resolve({ ok: false, error: reason });
        return;
      }
      try {
        const info = JSON.parse(out);
        resolve({
          ok: true,
          title: info.title || 'Video',
          platform: platformOf(info),
          duration: info.duration || null,
          maxHeight: maxHeightOf(info),
          uploader: info.uploader || info.channel || '',
          thumbnail: info.thumbnail || null
        });
      } catch (e) {
        log('INFO', 'video-info: could not parse the video data: ' + e.message, 'error');
        resolve({ ok: false, error: ms('infoFailed') });
      }
    });
  });
});

ipcMain.handle('start-download', (_e, opts) => startJob(opts));
ipcMain.handle('pause-download', (_e, jobId) => pauseJob(jobId));
ipcMain.handle('resume-download', (_e, jobId) => resumeJob(jobId));
ipcMain.handle('cancel-download', (_e, jobId) => cancelJob(jobId));

ipcMain.handle('get-history', () => history);
ipcMain.handle('open-file', (_e, filePath) => {
  if (!filePath || !fs.existsSync(filePath)) return { ok: false, error: ms('fileGone') };
  shell.openPath(filePath);
  return { ok: true };
});
ipcMain.handle('open-folder', (_e, filePath) => {
  const dir = filePath && fs.existsSync(filePath) ? path.dirname(filePath) : getDownloadDir();
  shell.openPath(dir);
  return { ok: true };
});
ipcMain.handle('delete-history', (_e, { id, deleteFile }) => {
  const idx = history.findIndex(h => h.id === id);
  if (idx === -1) return { ok: false, error: ms('entryNotFound') };
  const entry = history[idx];
  if (deleteFile && entry.path) { try { if (fs.existsSync(entry.path)) fs.unlinkSync(entry.path); } catch (e) { log('HISTORY', 'Could not delete file: ' + e.message, 'error'); } }
  history.splice(idx, 1);
  saveHistory();
  sendHistory();
  log('HISTORY', 'Deleted history entry: ' + entry.title);
  return { ok: true };
});
ipcMain.handle('redownload', (_e, id) => {
  const entry = history.find(h => h.id === id);
  if (!entry) return { ok: false, error: ms('entryNotFound') };
  return startJob({ url: entry.url, quality: 'highest', kind: 'video' });
});

ipcMain.handle('open-extension-folder', () => {
  const extDir = path.join(exeDir(), 'extension');
  const fallback = path.join(app.getAppPath(), 'extension');
  const dir = fs.existsSync(extDir) ? extDir : fallback;
  if (!fs.existsSync(dir)) return { ok: false, error: ms('extMissing') };
  shell.openPath(dir);
  return { ok: true };
});

ipcMain.handle('get-logs', () => logEntries);
ipcMain.handle('clear-logs', () => {
  logEntries.length = 0;
  try { fs.writeFileSync(logPath(), ''); } catch (_) {}
  return { ok: true };
});
ipcMain.handle('copy-logs', () => {
  const { clipboard } = require('electron');
  clipboard.writeText(logEntries.map(e => `[${e.time}] [${e.category}] [${e.level.toUpperCase()}] ${e.message}`).join('\n'));
  return { ok: true };
});

function compareVersions(a, b) {
  const pa = String(a).split('.').map(n => parseInt(n, 10) || 0);
  const pb = String(b).split('.').map(n => parseInt(n, 10) || 0);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] || 0) - (pb[i] || 0);
    if (d !== 0) return d;
  }
  return 0;
}
ipcMain.handle('check-updates', async () => {
  log('UPDATE', 'Checking for updates…');
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 15000);
    const res = await fetch(UPDATE_MANIFEST_URL, { signal: ctrl.signal, headers: { 'Accept': 'application/json' } });
    clearTimeout(timer);
    if (!res.ok) {
      log('UPDATE', `Update check failed: manifest returned HTTP ${res.status}`, 'error');
      return { ok: false, error: ms('updateHttp') + res.status + ms('updateHttpSuffix') };
    }
    const m = await res.json();
    if (!m || !m.version) {
      log('UPDATE', 'Update manifest is missing a version field.', 'error');
      return { ok: false, error: ms('manifestInvalid') };
    }
    if (compareVersions(m.version, APP_VERSION) > 0) {
      log('UPDATE', `New version available: ${m.version} (current ${APP_VERSION}).`);
      return { ok: true, update: true, version: m.version, notes: m.notes || '', url: m.url || RELEASES_URL };
    }
    log('UPDATE', `You are on the latest version (${APP_VERSION}).`);
    return { ok: true, update: false, version: APP_VERSION };
  } catch (e) {
    log('UPDATE', 'Update check failed: ' + e.message, 'error');
    return { ok: false, error: ms('updateUnreachable') };
  }
});

ipcMain.handle('open-external', (_e, url) => { shell.openExternal(url); return { ok: true }; });

// ---------------------------------------------------------------- local server (browser extension)
function startLocalServer() {
  const server = http.createServer((req, res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }
    const url = new URL(req.url, `http://127.0.0.1:${LOCAL_PORT}`);
    if (req.method === 'GET' && url.pathname === '/ping') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true, app: APP_NAME, version: APP_VERSION }));
      return;
    }
    if (req.method === 'GET' && url.pathname === '/state') {
      const s = loadSettings();
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ ok: true, app: APP_NAME, version: APP_VERSION, adblock: s.adblock !== false, downloadDir: getDownloadDir(), language: s.language || 'ar' }));
      return;
    }
    if (req.method === 'POST' && (url.pathname === '/download' || url.pathname === '/adblock' || url.pathname === '/adblock-stats' || url.pathname === '/extension-heartbeat')) {
      let body = '';
      req.on('data', c => { body += c; if (body.length > 10000) req.destroy(); });
      req.on('end', async () => {
        try {
          const data = JSON.parse(body || '{}');
          if (url.pathname === '/adblock') {
            const s = loadSettings();
            s.adblock = !!data.enabled;
            saveSettings(s);
            log('UPDATE', 'Ad Blocker ' + (s.adblock ? 'turned ON' : 'turned OFF') + ' from the browser extension.');
            if (win && !win.isDestroyed()) win.webContents.send('settings-changed', { key: 'adblock', value: s.adblock });
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ ok: true, adblock: s.adblock }));
            return;
          }
          if (url.pathname === '/adblock-stats') {
            const s = loadSettings();
            s.adblockBlocked = Number(data.blocked) || 0;
            saveSettings(s);
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ ok: true }));
            return;
          }
          if (url.pathname === '/extension-heartbeat') {
            const s = loadSettings();
            s.extLastSeen = Date.now();
            s.extVersion = String(data.version || '');
            saveSettings(s);
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ ok: true }));
            return;
          }
          // /download
          if (!data.url || !/^https?:\/\//i.test(String(data.url))) {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ ok: false, error: ms('urlRequired') }));
            return;
          }
          const result = await startJob({ url: String(data.url), quality: data.quality || 'highest', kind: data.kind });
          if (result.ok) {
            log('DOWNLOAD', `Download requested from browser extension: ${data.url}`);
            if (win && !win.isDestroyed()) { win.show(); win.focus(); }
          }
          res.writeHead(result.ok ? 200 : 409, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify(result));
        } catch (e) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ ok: false, error: 'Invalid request.' }));
        }
      });
      return;
    }
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: false, error: 'Not found.' }));
  });
  server.on('error', err => log('SYSTEM', `Local server (127.0.0.1:${LOCAL_PORT}) failed to start: ${err.message}`, 'error'));
  server.listen(LOCAL_PORT, '127.0.0.1', () => {
    log('SYSTEM', `Local server listening on 127.0.0.1:${LOCAL_PORT} for the browser extension.`);
  });
}

// ---------------------------------------------------------------- preview mode
const PREVIEW_STATE = {
  info: {
    title: 'Big Buck Bunny — 4K 60fps Official Trailer (Sample)',
    platform: 'YouTube', duration: 596, maxHeight: 2160, uploader: 'Blender Foundation',
    thumbnail: 'sample-thumb.png'
  },
  job: {
    id: 1, url: 'https://www.youtube.com/watch?v=aqz-KE-bpKQ', quality: '1080p',
    status: 'downloading', progress: 47.3, speed: '8.4 MiB/s', eta: '00:41',
    sizeTotal: '182.6 MiB', phase: 'downloading',
    title: 'Big Buck Bunny — 4K 60fps Official Trailer (Sample)', platform: 'YouTube'
  },
  history: [
    { id: 101, title: 'Big Buck Bunny — 4K 60fps Official Trailer', platform: 'YouTube', quality: '1080p', url: 'https://www.youtube.com/watch?v=aqz-KE-bpKQ', path: 'C:\\Users\\DELL\\Downloads\\SnapDL\\Big Buck Bunny.mp4', size: 191526400, date: new Date(Date.now() - 1000 * 60 * 42).toISOString(), status: 'done' },
    { id: 102, title: 'TikTok — funny cat compilation (no watermark)', platform: 'TikTok', quality: 'highest', url: 'https://www.tiktok.com/@example/video/7000000000000000000', path: 'C:\\Users\\DELL\\Downloads\\SnapDL\\funny cat.mp4', size: 12450000, date: new Date(Date.now() - 1000 * 60 * 60 * 5).toISOString(), status: 'done' },
    { id: 103, title: 'Neso Academy — Linear Algebra Lec 4', platform: 'YouTube', quality: 'audio', url: 'https://www.youtube.com/watch?v=example3', path: 'C:\\Users\\DELL\\Downloads\\SnapDL\\Linear Algebra Lec 4.mp3', size: 18200000, date: new Date(Date.now() - 1000 * 60 * 60 * 26).toISOString(), status: 'done' },
    { id: 104, title: 'Instagram Reel — Cairo street food tour', platform: 'Instagram', quality: '720p', url: 'https://www.instagram.com/reel/example4', path: 'C:\\Users\\DELL\\Downloads\\SnapDL\\Cairo street food.mp4', size: 48200000, date: new Date(Date.now() - 1000 * 60 * 60 * 49).toISOString(), status: 'done' }
  ],
  logs: [
    { time: new Date(Date.now() - 1000 * 60 * 3).toISOString(), category: 'DOWNLOAD', level: 'info', message: 'Starting download: https://www.youtube.com/watch?v=aqz-KE-bpKQ (quality: 1080p)' },
    { time: new Date(Date.now() - 1000 * 60 * 3).toISOString(), category: 'DOWNLOAD', level: 'info', message: 'Found: video 1920x1080 + audio, merging to MP4' },
    { time: new Date(Date.now() - 1000 * 60 * 12).toISOString(), category: 'DOWNLOAD', level: 'info', message: 'Finished: Big Buck Bunny — 4K 60fps Official Trailer (182.6 MB)' },
    { time: new Date(Date.now() - 1000 * 60 * 60).toISOString(), category: 'UPDATE', level: 'info', message: 'You are on the latest version (1.0.0).' },
    { time: new Date(Date.now() - 1000 * 60 * 61).toISOString(), category: 'SYSTEM', level: 'info', message: 'SnapDL started.' }
  ]
};

async function runPreviewCaptures() {
  const outDir = path.join(__dirname, '..', 'previews');
  fs.mkdirSync(outDir, { recursive: true });
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  await win.webContents.executeJavaScript(`document.body.classList.add('preview-mode')`).catch(() => {});
  win.webContents.send('preview-state', PREVIEW_STATE);
  await sleep(1800);
  const shots = [
    { file: '01-main-download.png', view: 'download', width: 1180, height: 1280 },
    { file: '02-history.png', view: 'history', width: 1180, height: 780 },
    { file: '03-settings.png', view: 'settings', width: 1180, height: 780 },
    { file: '04-about.png', view: 'settings', sub: 'about', width: 1180, height: 900 },
    { file: '05-youtube.png', view: 'youtube', width: 1180, height: 780, wait: 8000 },
    { file: '07-main-mobile-width.png', view: 'download', width: 390, height: 1500 }
  ];
  for (const s of shots) {
    if (s.width < 940 || s.height < 620) win.setMinimumSize(300, 300); // allow the narrow mobile-width shot
    win.setSize(s.width, s.height);
    win.webContents.send('preview-show-view', s.view);
    win.webContents.send('preview-state', PREVIEW_STATE); // re-apply (init may still overwrite)
    if (s.sub) win.webContents.send('preview-show-sub', s.sub);
    await sleep(s.wait || 900);
    if (s.file === '01-main-download.png' || s.file === '07-main-mobile-width.png' || s.file === '04-about.png') {
      // Show the view from the top (link input + job card all in frame).
      await win.webContents.executeJavaScript(`var m=document.querySelector('.main'); if(m) m.scrollTop=0; window.scrollTo(0,0);`).catch(() => {});
      await sleep(500);
    }
    const img = await win.webContents.capturePage();
    fs.writeFileSync(path.join(outDir, s.file), img.toPNG());
    log('SYSTEM', 'Preview captured: ' + s.file);
  }
  // 6th shot: mock YouTube watch page with the extension's floating button.
  win.setMinimumSize(940, 620);
  win.setSize(1180, 780);
  await win.loadFile(path.join(__dirname, 'src', 'preview-youtube.html'));
  await sleep(1200);
  const yt = await win.webContents.capturePage();
  fs.writeFileSync(path.join(outDir, '06-youtube-overlay.png'), yt.toPNG());
  log('SYSTEM', 'Preview captured: 06-youtube-overlay.png');
  app.quit();
}

// ---------------------------------------------------------------- lifecycle
app.whenReady().then(() => {
  loadHistory();
  log('SYSTEM', 'SnapDL started.');
  startLocalServer();
  createWindow();
  if (PREVIEW_MODE) {
    win.webContents.on('console-message', (_e, _level, msg) => { if (String(msg).startsWith('[yt]')) console.log(msg); });
    win.webContents.once('did-finish-load', () => { runPreviewCaptures().catch(e => { log('SYSTEM', 'Preview failed: ' + e.message, 'error'); app.quit(); }); });
  }
  app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
});
app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
app.on('before-quit', () => {
  for (const job of jobs.values()) {
    if (job.child) killChild(job.child);
    if (job._controller) { try { job._controller.abort(); } catch (_) {} }
  }
});

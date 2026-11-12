'use strict';
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('snapdlAPI', {
  appInfo: () => ipcRenderer.invoke('app-info'),
  getSettings: () => ipcRenderer.invoke('get-settings'),
  setSetting: (key, value) => ipcRenderer.invoke('set-setting', { key, value }),
  getAdblockState: () => ipcRenderer.invoke('get-adblock-state'),
  chooseFolder: () => ipcRenderer.invoke('choose-folder'),
  fetchInfo: (url) => ipcRenderer.invoke('fetch-info', url),
  startDownload: (opts) => ipcRenderer.invoke('start-download', opts),
  pauseDownload: (jobId) => ipcRenderer.invoke('pause-download', jobId),
  resumeDownload: (jobId) => ipcRenderer.invoke('resume-download', jobId),
  cancelDownload: (jobId) => ipcRenderer.invoke('cancel-download', jobId),
  getHistory: () => ipcRenderer.invoke('get-history'),
  openFile: (p) => ipcRenderer.invoke('open-file', p),
  openFolder: (p) => ipcRenderer.invoke('open-folder', p),
  deleteHistory: (id, deleteFile) => ipcRenderer.invoke('delete-history', { id, deleteFile }),
  redownload: (id) => ipcRenderer.invoke('redownload', id),
  getLogs: () => ipcRenderer.invoke('get-logs'),
  clearLogs: () => ipcRenderer.invoke('clear-logs'),
  copyLogs: () => ipcRenderer.invoke('copy-logs'),
  checkUpdates: () => ipcRenderer.invoke('check-updates'),
  openExternal: (url) => ipcRenderer.invoke('open-external', url),
  openExtensionFolder: () => ipcRenderer.invoke('open-extension-folder'),
  // Download tool (yt-dlp): update to the latest release / report its version.
  updateTool: () => ipcRenderer.invoke('update-tool'),
  toolVersion: () => ipcRenderer.invoke('tool-version'),
  // Internet speed test (Cloudflare; only starts when the user runs it).
  runSpeedTest: () => ipcRenderer.invoke('speed-test-run'),
  cancelSpeedTest: () => ipcRenderer.invoke('speed-test-cancel'),
  onSpeedTestSample: (cb) => ipcRenderer.on('speed-test-sample', (_e, sample) => cb(sample)),
  // In-app app update: download the package, then install it.
  downloadUpdate: (url, fileName) => {
    if (url && typeof url === 'object') return ipcRenderer.invoke('download-update', url);
    return ipcRenderer.invoke('download-update', { url, fileName });
  },
  // v1.0.8: differential update via electron-updater (installed app).
  downloadAppUpdate: () => ipcRenderer.invoke('download-app-update'),
  onUpdateDownloadProgress: (cb) => ipcRenderer.on('update-download-progress', (_e, progress) => cb(progress)),
  installUpdate: (p) => {
    if (p && typeof p === 'object') return ipcRenderer.invoke('install-update', p);
    return ipcRenderer.invoke('install-update', { path: p });
  },
  setUpdateTonight: (value) => {
    if (value && typeof value === 'object') return ipcRenderer.invoke('set-update-tonight', value);
    return ipcRenderer.invoke('set-update-tonight', { value });
  },
  onDownloadList: (cb) => ipcRenderer.on('download-list', (_e, list) => cb(list)),
  onHistoryUpdated: (cb) => ipcRenderer.on('history-updated', (_e, h) => cb(h)),
  onLogAdded: (cb) => ipcRenderer.on('log-added', (_e, entry) => cb(entry)),
  onSettingsChanged: (cb) => ipcRenderer.on('settings-changed', (_e, change) => cb(change)),
  onPreviewState: (cb) => ipcRenderer.on('preview-state', (_e, state) => cb(state)),
  onPreviewShowView: (cb) => ipcRenderer.on('preview-show-view', (_e, view) => cb(view)),
  onPreviewShowSub: (cb) => ipcRenderer.on('preview-show-sub', (_e, sub) => cb(sub))
});

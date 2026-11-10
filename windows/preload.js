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
  onDownloadList: (cb) => ipcRenderer.on('download-list', (_e, list) => cb(list)),
  onHistoryUpdated: (cb) => ipcRenderer.on('history-updated', (_e, h) => cb(h)),
  onLogAdded: (cb) => ipcRenderer.on('log-added', (_e, entry) => cb(entry)),
  onSettingsChanged: (cb) => ipcRenderer.on('settings-changed', (_e, change) => cb(change)),
  onPreviewState: (cb) => ipcRenderer.on('preview-state', (_e, state) => cb(state)),
  onPreviewShowView: (cb) => ipcRenderer.on('preview-show-view', (_e, view) => cb(view)),
  onPreviewShowSub: (cb) => ipcRenderer.on('preview-show-sub', (_e, sub) => cb(sub))
});

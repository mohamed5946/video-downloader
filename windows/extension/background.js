/* SnapDL extension — background service worker (MV3).
   - Right-click menu: "Download with SnapDL" on links, images, video, audio.
   - Optional interception of browser downloads (OFF by default; enable in popup).
   - Talks to the SnapDL desktop app's local server on 127.0.0.1:47811. */
'use strict';

const SERVER = 'http://127.0.0.1:47811';

// Notification strings follow the desktop app's language (synced via /state).
let extLang = 'ar';
const BG_STR = {
  en: {
    menuDownload: 'Download with SnapDL', sentTitle: 'Sent to SnapDL',
    sentBody: 'Your download was sent to the SnapDL app.',
    interceptedBody: 'Download intercepted and sent to SnapDL.',
    refused: 'SnapDL refused the download.',
    notRunningTitle: 'SnapDL isn’t running',
    notRunningBody: 'Open the SnapDL desktop app first, then try again.',
    noLink: 'This page has no downloadable link.'
  },
  ar: {
    menuDownload: 'تنزيل بواسطة SnapDL', sentTitle: 'تم الإرسال إلى SnapDL',
    sentBody: 'تم إرسال التنزيل إلى تطبيق SnapDL.',
    interceptedBody: 'تم اعتراض التنزيل وإرساله إلى SnapDL.',
    refused: 'رفض SnapDL التنزيل.',
    notRunningTitle: 'تطبيق SnapDL لا يعمل',
    notRunningBody: 'افتح تطبيق SnapDL أولًا، ثم حاول مرة أخرى.',
    noLink: 'هذه الصفحة لا تحتوي على رابط قابل للتنزيل.'
  }
};
function BL(k) { return (BG_STR[extLang] && BG_STR[extLang][k]) || BG_STR.en[k] || k; }
function updateMenuTitle() { try { chrome.contextMenus.update('snapdl-download', { title: BL('menuDownload') }); } catch (_) {} }
chrome.storage.local.get({ snapdlLang: 'ar' }, items => {
  extLang = items.snapdlLang === 'en' ? 'en' : 'ar';
  updateMenuTitle();
});

async function sendToSnapDL(url, kind) {
  const res = await fetch(SERVER + '/download', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ url, kind: kind || undefined })
  });
  return res.json();
}

function notify(title, message) {
  chrome.notifications.create({
    type: 'basic',
    iconUrl: 'icons/icon128.png',
    title: 'SnapDL',
    message
  }).catch(() => {});
}

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: 'snapdl-download',
    title: 'Download with SnapDL',
    contexts: ['link', 'image', 'video', 'audio']
  });
  chrome.storage.sync.get({ intercept: false, adblock: true }, items => {
    chrome.storage.sync.set({ intercept: !!items.intercept, adblock: items.adblock !== false });
    applyAdblock(items.adblock !== false);
  });
  chrome.storage.local.get({ blockedCount: 0 }, items => {
    chrome.storage.local.set({ blockedCount: items.blockedCount || 0 });
  });
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (info.menuItemId !== 'snapdl-download') return;
  const url = info.linkUrl || info.srcUrl;
  if (!url || !/^https?:\/\//i.test(url)) return;
  sendToSnapDL(url).then(res => {
    if (res && res.ok) notify(BL('sentTitle'), BL('sentBody'));
    else notify('SnapDL', (res && res.error) || BL('refused'));
  }).catch(() => {
    notify(BL('notRunningTitle'), BL('notRunningBody'));
  });
});

// Intercept browser downloads only when the user enabled it in the popup.
chrome.downloads.onCreated.addListener(async (item) => {
  const { intercept } = await chrome.storage.sync.get({ intercept: false });
  if (!intercept) return;
  if (!item.url || !/^https?:\/\//i.test(item.url)) return;
  try {
    await chrome.downloads.cancel(item.id);
    await chrome.downloads.erase({ id: item.id });
  } catch (_) { /* already finished or gone */ }
  sendToSnapDL(item.url, 'file').then(res => {
    if (res && res.ok) notify(BL('sentTitle'), BL('interceptedBody'));
    else notify('SnapDL', (res && res.error) || BL('refused'));
  }).catch(() => {
    notify(BL('notRunningTitle'), BL('notRunningBody'));
  });
});

// Messages from the popup.
chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg && msg.type === 'ping') {
    fetch(SERVER + '/ping')
      .then(r => r.json())
      .then(d => sendResponse({ running: true, version: d.version }))
      .catch(() => sendResponse({ running: false }));
    return true; // async response
  }
  if (msg && msg.type === 'send-page') {
    chrome.tabs.query({ active: true, currentWindow: true }, tabs => {
      const url = tabs && tabs[0] && tabs[0].url;
      if (!url || !/^https?:\/\//i.test(url)) { sendResponse({ ok: false, error: BL('noLink') }); return; }
      sendToSnapDL(url, 'video')
        .then(res => sendResponse(res))
        .catch(() => sendResponse({ ok: false, error: BL('notRunningBody') }));
    });
    return true;
  }
  if (msg && msg.type === 'get-adblock') {
    chrome.storage.sync.get({ adblock: true }, items => {
      chrome.storage.local.get({ blockedCount: 0 }, local => {
        sendResponse({ enabled: items.adblock !== false, blocked: local.blockedCount || 0 });
      });
    });
    return true;
  }
  if (msg && msg.type === 'set-adblock') {
    const enabled = !!msg.enabled;
    chrome.storage.sync.set({ adblock: enabled }, () => {
      applyAdblock(enabled);
      // Tell the desktop app so its Settings screen stays in sync.
      fetch(SERVER + '/adblock', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ enabled })
      }).catch(() => {});
      sendResponse({ ok: true, enabled });
    });
    return true;
  }
  return false;
});

// ---------------------------------------------------------------- ad blocker
// Browser-only blocking (declarativeNetRequest, EasyList-based ruleset).
// It does NOT block YouTube video ads — those come from the same domain as
// the video itself. The user downloads YouTube videos instead.
function applyAdblock(enabled) {
  if (!chrome.declarativeNetRequest || !chrome.declarativeNetRequest.updateEnabledRulesets) return;
  chrome.declarativeNetRequest.updateEnabledRulesets(
    enabled ? { enableRulesetIds: ['ads'] } : { disableRulesetIds: ['ads'] }
  ).catch(() => {});
}

// Toggle from the popup or the app's Settings screen.
chrome.storage.onChanged.addListener((changes, area) => {
  if (area === 'sync' && changes.adblock) applyAdblock(changes.adblock.newValue !== false);
});

// Count blocked requests (onRuleMatchedDebug only fires for unpacked
// extensions — ours is loaded unpacked in developer mode, so it works).
if (chrome.declarativeNetRequest && chrome.declarativeNetRequest.onRuleMatchedDebug) {
  let pendingReport = 0;
  chrome.declarativeNetRequest.onRuleMatchedDebug.addListener(() => {
    chrome.storage.local.get({ blockedCount: 0 }, items => {
      const n = (items.blockedCount || 0) + 1;
      chrome.storage.local.set({ blockedCount: n });
      pendingReport++;
    });
  });
  // Report the count to the desktop app every minute.
  setInterval(() => {
    if (!pendingReport) return;
    pendingReport = 0;
    chrome.storage.local.get({ blockedCount: 0 }, items => {
      fetch(SERVER + '/adblock-stats', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ blocked: items.blockedCount || 0 })
      }).catch(() => {});
    });
  }, 60000);
}

// Stay in sync with the desktop app: it is the other place the toggle lives.
async function syncWithApp() {
  try {
    const res = await fetch(SERVER + '/state');
    const state = await res.json();
    if (state && state.language && state.language !== extLang) {
      extLang = state.language === 'en' ? 'en' : 'ar';
      chrome.storage.local.set({ snapdlLang: extLang });
      updateMenuTitle();
    }
    if (state && typeof state.adblock === 'boolean') {
      const cur = await chrome.storage.sync.get({ adblock: true });
      if ((cur.adblock !== false) !== state.adblock) {
        chrome.storage.sync.set({ adblock: state.adblock });
        applyAdblock(state.adblock);
      }
    }
  } catch (_) { /* app not running — keep the last known setting */ }
  // Heartbeat so the app can show "Extension connected".
  try {
    await fetch(SERVER + '/extension-heartbeat', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ version: chrome.runtime.getManifest().version })
    });
  } catch (_) {}
}
setInterval(syncWithApp, 30000);
syncWithApp();

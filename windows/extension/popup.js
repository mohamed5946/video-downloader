'use strict';
/* SnapDL extension popup — strings follow the desktop app's language. */
const STR = {
  en: {
    checking: 'Checking SnapDL…', running: 'SnapDL is running',
    notRunning: 'SnapDL is NOT running — open the app first',
    sendPage: "Download this page's video", sending: 'Sending…',
    sent: 'Sent to SnapDL — downloading…', sendFail: 'Could not send to SnapDL.',
    noLink: 'This page has no downloadable link.',
    intercept: 'Intercept browser downloads',
    interceptSub: 'Send every browser download to SnapDL instead (IDM-style).',
    interceptOn: 'Download interception ON — browser downloads will go to SnapDL.',
    interceptOff: 'Download interception OFF.',
    adblock: 'Ad Blocker',
    adblockSub: 'Blocks ads in this browser (EasyList rules). YouTube video ads are not blocked.',
    adblockOn: 'Ad Blocker ON.', adblockOff: 'Ad Blocker OFF.',
    adsBlocked: ' ads blocked', headSub: 'Download with SnapDL',
    foot: 'SnapDL desktop app must be running.'
  },
  ar: {
    checking: 'جارٍ التحقق من SnapDL…', running: 'SnapDL يعمل',
    notRunning: 'SnapDL لا يعمل — افتح التطبيق أولًا',
    sendPage: 'تنزيل فيديو هذه الصفحة', sending: 'جارٍ الإرسال…',
    sent: 'تم الإرسال إلى SnapDL — جارٍ التنزيل…', sendFail: 'تعذّر الإرسال إلى SnapDL.',
    noLink: 'هذه الصفحة لا تحتوي على رابط قابل للتنزيل.',
    intercept: 'اعتراض تنزيلات المتصفح',
    interceptSub: 'إرسال كل تنزيلات المتصفح إلى SnapDL بدلًا من ذلك (مثل IDM).',
    interceptOn: 'اعتراض التنزيلات مفعّل — تنزيلات المتصفح ستذهب إلى SnapDL.',
    interceptOff: 'اعتراض التنزيلات متوقف.',
    adblock: 'مانع الإعلانات',
    adblockSub: 'يحظر الإعلانات في هذا المتصفح (قواعد EasyList). إعلانات فيديو يوتيوب لا تُحظر.',
    adblockOn: 'مانع الإعلانات يعمل.', adblockOff: 'مانع الإعلانات متوقف.',
    adsBlocked: ' إعلان محظور', headSub: 'التنزيل بواسطة SnapDL',
    foot: 'يجب أن يعمل تطبيق SnapDL.'
  }
};
let lang = 'ar';
function L(k) { return (STR[lang] && STR[lang][k]) || STR.en[k] || k; }
function fmt(n) { return Number(n || 0).toLocaleString('en-US'); }

const dot = document.getElementById('dot');
const statusText = document.getElementById('statusText');
const msg = document.getElementById('msg');
const sendBtn = document.getElementById('sendPageBtn');
const toggle = document.getElementById('interceptToggle');
const adblockToggle = document.getElementById('adblockToggle');
const blockedLabel = document.getElementById('blockedLabel');

function applyStrings() {
  document.documentElement.lang = lang;
  document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
  document.getElementById('headSub').textContent = L('headSub');
  sendBtn.textContent = L('sendPage');
  document.getElementById('interceptLabel').textContent = L('intercept');
  document.getElementById('interceptSub').textContent = L('interceptSub');
  document.getElementById('adblockLabel').textContent = L('adblock');
  document.getElementById('adblockSub').textContent = L('adblockSub');
  document.getElementById('footNote').innerHTML = L('foot') + '<br>v1.0.0';
  if (statusText.dataset.state === 'checking') statusText.textContent = L('checking');
}

chrome.storage.local.get({ snapdlLang: 'ar' }, items => {
  lang = items.snapdlLang === 'en' ? 'en' : 'ar';
  applyStrings();
});

chrome.runtime.sendMessage({ type: 'get-adblock' }, res => {
  if (!res) return;
  adblockToggle.checked = !!res.enabled;
  blockedLabel.textContent = fmt(res.blocked) + L('adsBlocked');
});
adblockToggle.addEventListener('change', () => {
  chrome.runtime.sendMessage({ type: 'set-adblock', enabled: adblockToggle.checked }, res => {
    msg.textContent = adblockToggle.checked ? L('adblockOn') : L('adblockOff');
  });
});

function setStatus(running, version) {
  dot.classList.toggle('on', !!running);
  statusText.dataset.state = running ? 'running' : 'not-running';
  statusText.textContent = running
    ? L('running') + (version ? ' (v' + version + ')' : '')
    : L('notRunning');
}

statusText.dataset.state = 'checking';
statusText.textContent = L('checking');
chrome.runtime.sendMessage({ type: 'ping' }, res => {
  setStatus(res && res.running, res && res.version);
});

chrome.storage.sync.get({ intercept: false }, items => {
  toggle.checked = !!items.intercept;
});
toggle.addEventListener('change', () => {
  chrome.storage.sync.set({ intercept: toggle.checked });
  msg.textContent = toggle.checked ? L('interceptOn') : L('interceptOff');
});

sendBtn.addEventListener('click', () => {
  msg.textContent = L('sending');
  chrome.runtime.sendMessage({ type: 'send-page' }, res => {
    if (res && res.ok) msg.textContent = L('sent');
    else msg.textContent = (res && res.error) || L('sendFail');
  });
});

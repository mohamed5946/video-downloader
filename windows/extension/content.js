/* SnapDL content script — floating "Download video" button over playing videos.
   IMPORTANT: we send the PAGE URL to the SnapDL app, never the <video> blob
   src — blob URLs are not the real file and cannot be downloaded. The app
   downloads the video properly with yt-dlp. */
(function () {
  'use strict';
  var SERVER = 'http://127.0.0.1:47811';
  var btn = null;
  var toastEl = null;
  var currentVideo = null;
  var extLang = 'ar';
  var STRINGS = {
    en: { download: 'Download video', downloadTitle: 'Download this video with SnapDL', sending: 'Sending…', sent: 'Sent to SnapDL — downloading…', refused: 'SnapDL refused the download.', notRunning: 'SnapDL isn’t running — open the SnapDL app first.' },
    ar: { download: 'تنزيل الفيديو', downloadTitle: 'تنزيل هذا الفيديو بواسطة SnapDL', sending: 'جارٍ الإرسال…', sent: 'تم الإرسال إلى SnapDL — جارٍ التنزيل…', refused: 'رفض SnapDL التنزيل.', notRunning: 'تطبيق SnapDL لا يعمل — افتح التطبيق أولًا.' }
  };
  function L(k) { return (STRINGS[extLang] && STRINGS[extLang][k]) || STRINGS.en[k]; }
  function btnLabel() { return '<span class="snapdl-dl-ic">↓</span> ' + L('download'); }
  function refreshLabel() {
    if (!btn) return;
    if (btn.dataset.lang !== extLang) {
      btn.innerHTML = btnLabel();
      btn.title = L('downloadTitle');
      btn.dataset.lang = extLang;
    }
  }
  chrome.storage.local.get({ snapdlLang: 'ar' }, function (items) {
    extLang = items.snapdlLang === 'en' ? 'en' : 'ar';
    refreshLabel();
  });
  chrome.storage.onChanged.addListener(function (changes, area) {
    if (area === 'local' && changes.snapdlLang) {
      extLang = changes.snapdlLang.newValue === 'en' ? 'en' : 'ar';
      refreshLabel();
    }
  });

  function showToast(msg, ok) {
    if (!toastEl) {
      toastEl = document.createElement('div');
      toastEl.className = 'fetch-toast';
      document.documentElement.appendChild(toastEl);
    }
    toastEl.textContent = msg;
    toastEl.classList.toggle('fetch-toast-error', !ok);
    toastEl.classList.add('fetch-toast-show');
    clearTimeout(showToast._t);
    showToast._t = setTimeout(function () { toastEl.classList.remove('fetch-toast-show'); }, 3500);
  }

  function sendToSnapDL(url, kind) {
    return fetch(SERVER + '/download', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ url: url, kind: kind || 'video' })
    }).then(function (r) { return r.json(); });
  }

  function ensureButton() {
    if (btn) return btn;
    btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'snapdl-dl-btn';
    btn.innerHTML = btnLabel();
    btn.title = L('downloadTitle');
    btn.dataset.lang = extLang;
    btn.addEventListener('click', function (ev) {
      ev.preventDefault();
      ev.stopPropagation();
      btn.classList.add('snapdl-dl-busy');
      btn.innerHTML = '<span class="snapdl-dl-ic">…</span> ' + L('sending');
      // Send the PAGE url — the app fetches the real video via yt-dlp.
      sendToSnapDL(window.location.href, 'video').then(function (res) {
        if (res && res.ok) {
          showToast(L('sent'), true);
        } else {
          showToast((res && res.error) || L('refused'), false);
        }
      }).catch(function () {
        showToast(L('notRunning'), false);
      }).finally(function () {
        btn.classList.remove('snapdl-dl-busy');
        refreshLabel();
      });
    });
    document.documentElement.appendChild(btn);
    return btn;
  }

  function bestVideo() {
    var videos = Array.prototype.slice.call(document.querySelectorAll('video'));
    var scored = videos.map(function (v) {
      var r = v.getBoundingClientRect();
      var visible = r.width > 160 && r.height > 90 && r.bottom > 0 && r.top < window.innerHeight && r.right > 0 && r.left < window.innerWidth;
      var score = (visible ? 1000 : 0) + (r.width * r.height) + (v.duration > 0 ? 100 : 0) + (!v.paused ? 50 : 0);
      return { v: v, r: r, score: score, visible: visible };
    }).filter(function (x) { return x.visible && x.v.readyState >= 1; });
    if (!scored.length) return null;
    scored.sort(function (a, b) { return b.score - a.score; });
    return scored[0];
  }

  function placeButton() {
    var hit = bestVideo();
    if (!hit) {
      if (btn) btn.classList.remove('snapdl-dl-show');
      currentVideo = null;
      return;
    }
    currentVideo = hit.v;
    var b = ensureButton();
    var r = hit.r;
    // Keep the button inside the video's top-right corner.
    var top = Math.max(8, r.top + 12);
    var left = Math.min(window.innerWidth - 190, r.right - 178);
    b.style.top = top + 'px';
    b.style.left = Math.max(8, left) + 'px';
    b.classList.add('snapdl-dl-show');
  }

  var ticking = false;
  function schedule() {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(function () { ticking = false; refreshLabel(); placeButton(); });
  }

  var observer = new MutationObserver(schedule);
  observer.observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ['src'] });
  document.addEventListener('play', schedule, true);
  document.addEventListener('pause', schedule, true);
  document.addEventListener('loadedmetadata', schedule, true);
  window.addEventListener('scroll', schedule, { passive: true });
  window.addEventListener('resize', schedule);
  setInterval(schedule, 1500);
  schedule();

  // Allow the popup / background to ask for the current page URL.
  chrome.runtime.onMessage.addListener(function (msg, _sender, sendResponse) {
    if (msg && msg.type === 'fetch-page-url') sendResponse({ url: window.location.href });
    return false;
  });
})();

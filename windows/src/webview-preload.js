'use strict';
/* SnapDL webview preload — injects the floating "Download video" button
   into pages loaded in the in-app YouTube tab (youtube.com).
   Sends the PAGE url to the SnapDL local server — never a <video> blob src. */
(function () {
  var SERVER = 'http://127.0.0.1:47811';
  var btn = null;
  var toastEl = null;

  // Overlay strings follow the app language (renderer sets window.__snapdlLang).
  var STRINGS = {
    en: { download: 'Download video', downloadTitle: 'Download this video with SnapDL', sending: 'Sending…', sent: 'Sent to SnapDL — downloading…', refused: 'SnapDL refused the download.', notRunning: 'SnapDL isn’t running — open the SnapDL app first.' },
    ar: { download: 'تنزيل الفيديو', downloadTitle: 'تنزيل هذا الفيديو بواسطة SnapDL', sending: 'جارٍ الإرسال…', sent: 'تم الإرسال إلى SnapDL — جارٍ التنزيل…', refused: 'رفض SnapDL التنزيل.', notRunning: 'تطبيق SnapDL لا يعمل — افتح التطبيق أولًا.' }
  };
  function lang() { return (window.__snapdlLang === 'en') ? 'en' : 'ar'; }
  function L(k) { return STRINGS[lang()][k]; }
  function btnLabel() { return '<span class="snapdl-dl-ic">↓</span> ' + L('download'); }
  function refreshLabel() {
    if (!btn) return;
    if (btn.dataset.lang !== lang()) {
      btn.innerHTML = btnLabel();
      btn.title = L('downloadTitle');
      btn.dataset.lang = lang();
    }
  }

  function css() {
    if (document.getElementById('snapdl-wv-style')) return;
    var s = document.createElement('style');
    s.id = 'snapdl-wv-style';
    s.textContent = [
      '.snapdl-dl-btn{position:fixed;z-index:2147483647;display:none;align-items:center;gap:8px;padding:10px 16px;',
      'font-family:"Cairo","Segoe UI",system-ui,Arial,sans-serif;font-size:14px;font-weight:700;color:#fff;cursor:pointer;',
      'border:1px solid rgba(255,255,255,.45);border-radius:999px;',
      'background:linear-gradient(135deg,rgba(78,122,142,.94),rgba(62,98,116,.94));',
      'box-shadow:0 10px 28px rgba(31,42,51,.55),inset 0 1px 0 rgba(255,255,255,.4);',
      'opacity:0;transform:translateY(-6px) scale(.96);transition:opacity .3s,transform .3s,filter .2s;}',
      '.snapdl-dl-btn.snapdl-dl-show{display:inline-flex;opacity:1;transform:translateY(0) scale(1);}',
      '.snapdl-dl-btn:hover{filter:brightness(1.12);}',
      '.snapdl-dl-ic{display:inline-flex;align-items:center;justify-content:center;width:22px;height:22px;border-radius:50%;background:rgba(255,255,255,.25);font-size:14px;font-weight:800;}',
      '.snapdl-toast{position:fixed;left:50%;bottom:28px;transform:translate(-50%,80px);z-index:2147483647;padding:12px 20px;border-radius:999px;',
      'font-family:"Cairo","Segoe UI",system-ui,Arial,sans-serif;font-size:14px;font-weight:650;color:#f7f4e9;background:rgba(31,42,51,.94);',
      'border:1px solid rgba(255,255,255,.25);box-shadow:0 14px 34px rgba(31,42,51,.6);opacity:0;transition:all .4s;pointer-events:none;max-width:88vw;text-align:center;}',
      '.snapdl-toast.snapdl-toast-show{opacity:1;transform:translate(-50%,0);}',
      '.snapdl-toast.snapdl-toast-error{border-color:rgba(251,113,133,.6);color:#fecdd3;}'
    ].join('');
    document.documentElement.appendChild(s);
  }

  function showToast(msg, ok) {
    css();
    if (!toastEl) {
      toastEl = document.createElement('div');
      toastEl.className = 'snapdl-toast';
      document.documentElement.appendChild(toastEl);
    }
    toastEl.textContent = msg;
    toastEl.classList.toggle('snapdl-toast-error', !ok);
    toastEl.classList.add('snapdl-toast-show');
    clearTimeout(showToast._t);
    showToast._t = setTimeout(function () { toastEl.classList.remove('snapdl-toast-show'); }, 3500);
  }

  function ensureButton() {
    css();
    if (btn) return btn;
    btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'snapdl-dl-btn';
    btn.innerHTML = btnLabel();
    btn.title = L('downloadTitle');
    btn.dataset.lang = lang();
    btn.addEventListener('click', function (ev) {
      ev.preventDefault();
      ev.stopPropagation();
      btn.innerHTML = '<span class="snapdl-dl-ic">…</span> ' + L('sending');
      fetch(SERVER + '/download', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ url: window.location.href, kind: 'video' })
      }).then(function (r) { return r.json(); }).then(function (res) {
        showToast(res && res.ok ? L('sent') : ((res && res.error) || L('refused')), !!(res && res.ok));
      }).catch(function () {
        showToast(L('notRunning'), false);
      }).finally(function () {
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
    if (!hit) { if (btn) btn.classList.remove('snapdl-dl-show'); return; }
    var b = ensureButton();
    var r = hit.r;
    b.style.top = Math.max(8, r.top + 12) + 'px';
    b.style.left = Math.max(8, Math.min(window.innerWidth - 190, r.right - 178)) + 'px';
    b.classList.add('snapdl-dl-show');
  }

  var ticking = false;
  function schedule() {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(function () { ticking = false; refreshLabel(); placeButton(); });
  }

  // YouTube is a single-page app: watch for navigation + video changes.
  new MutationObserver(schedule).observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ['src'] });
  document.addEventListener('play', schedule, true);
  document.addEventListener('pause', schedule, true);
  document.addEventListener('loadedmetadata', schedule, true);
  window.addEventListener('scroll', schedule, { passive: true });
  window.addEventListener('resize', schedule);
  setInterval(schedule, 1500);
  schedule();
})();

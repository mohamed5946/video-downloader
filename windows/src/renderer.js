'use strict';
/* SnapDL renderer — wires every control to the main process.
   Language: Arabic default, English available. Theme: dark / light / system.
   If window.snapdlAPI is missing (plain browser render), a mock API is used
   so the UI still renders with sample data. */
(function () {
  const $ = id => document.getElementById(id);

  // ================= i18n =================
  const I18N = {
    en: {
      brandSub: 'Video Downloader', navDownload: 'Download', navYoutube: 'YouTube', navHistory: 'History', navSpeed: 'Speed', navSettings: 'Settings',
      checkUpdates: 'Check for updates',
      dlTitle1: 'Paste a link.', dlTitle2: 'Get the video.',
      dlSub: 'YouTube · TikTok · Instagram · Facebook · X — free, no ads, no sign-in.',
      videoLink: 'Video link', urlPlaceholder: 'https://www.youtube.com/watch?v=…  or  TikTok / Instagram / Facebook / X link',
      getInfo: 'Get info', quality: 'Quality', qHighest: 'Highest', qHighestSub: 'Best available', qFullHD: 'Full HD',
      qLowest: 'Lowest', qLowestSub: 'Smallest file', qAudio: 'Audio only',
      saveTo: 'Save to', change: 'Change', download: 'Download',
      browserTitle: 'Browser integration — like IDM',
      browserSub: 'Install the SnapDL extension in Edge or Chrome and a “Download video” button appears over any video playing in the browser. Right-click any link or image → Download with SnapDL. The app must be running for the button to work.',
      openExtFolder: 'Open extension folder',
      ytInApp: 'in SnapDL',
      ytSub: 'Watch YouTube inside the app. Ads are shown normally. Use the button below to download the video you\'re watching.',
      ytDownloadBtn: 'Download this video',
      ytNote: 'Note: Google sign-in inside the app is best-effort — Google may block sign-in in embedded views. If it doesn\'t work, sign in from Edge or Chrome instead. Your downloads still work without signing in.',
      histTitle1: 'Download', histTitle2: 'history',
      histSub: 'Everything you downloaded, stored on this device only.',
      openFolder: 'Open download folder', histEmpty1: 'No downloads yet.',
      histEmpty2: 'Paste a link on the Download page and your history will appear here.',
      settingsTitle: 'Settings', settingsSub: 'Tap a row to open its own screen.',
      setAppearance: 'Appearance', setAppearanceSub: 'Dark · Light · Follow system',
      setLanguage: 'Language', setDownloads: 'Downloads', setDownloadsSub: 'Folder · Default quality · Wi-Fi only',
      setAdblock: 'Ad Blocker', setAdblockSub: 'Block ads in your browser',
      setExtension: 'Browser Extension', setUpdates: 'Updates', setUpdatesSub: 'Check for a new version',
      setLogs: 'Diagnostics Log', setLogsSub: 'Every event, with the exact reason when something fails',
      setAbout: 'About', back: 'Back',
      appearanceDesc: 'Choose how SnapDL looks. It applies immediately.',
      themeDark: 'Dark', themeDarkSub: 'Dark glass, easy on the eyes at night',
      themeLight: 'Light', themeLightSub: 'Bright and clean',
      themeSystem: 'Follow system', themeSystemSub: 'Match Windows light / dark mode',
      languageDesc: 'Applies immediately.',
      defaultQuality: 'Default quality',
      wifiOnly: 'Wi-Fi only', wifiOnlySub: 'Only download when you\'re connected to Wi-Fi',
      maxConc: 'Max simultaneous downloads', maxConcSub: 'How many downloads run at the same time',
      adblockDesc: 'Blocks ads inside Edge and Chrome, using the SnapDL browser extension (EasyList rules). Browser only — nothing system-wide.',
      adblockToggle: 'Ad Blocker', adblockBlocked: 'Ads blocked', adblockRules: 'Filter rules',
      adblockNote: 'YouTube video ads are not blocked — they come from the same domain as the video. Download the video with SnapDL instead.',
      extStatus: 'Status', extServer: 'Local server',
      extGuide: 'Install it once — load unpacked in developer mode:\nEdge → edge://extensions → Developer mode → Load unpacked → pick the extension folder.\nChrome → chrome://extensions → same steps.\nThe SnapDL app must be running for the video button to work.',
      updCurrent: 'Current version', autoCheck: 'Check automatically',
      autoCheckSub: 'Check for a new version when SnapDL starts',
      logsDesc: 'Every event, with the exact reason when something fails. This is how bugs get found fast.',
      logAll: 'All categories', logErrors: 'Errors only', copyLog: 'Copy log', clearLog: 'Clear log',
      aboutDesc: 'A fast, beautiful downloader for YouTube, TikTok, Instagram, Facebook and X. Paste a link, pick a quality, and the video is yours — no ads, no accounts, no watermarks.',
      aboutDev: 'Developer', aboutPlatform: 'Platform',
      viewPortfolio: 'View my portfolio ↗',
      toastPasteFirst: 'Paste a video link first.', toastFolderUpdated: 'Download folder updated.',
      toastLogCopied: 'Log copied to clipboard.', toastFinished: 'Download finished: ',
      toastQueued: 'Queued — it will start when a slot frees up.',
      toastNoVideo: 'Open a YouTube video first, then tap Download.',
      toastExtMissing: 'Extension folder not found.',
      phaseStarting: 'Starting…', phaseDownloading: 'Downloading…', phaseMerging: 'Merging video + audio…',
      phaseConverting: 'Converting…', phaseFinishing: 'Finishing…', phaseQueued: 'Waiting for a free slot…',
      phasePaused: 'Paused — your progress is saved, resume anytime.',
      speed: 'Speed', eta: 'ETA', size: 'Size',
      pause: '❚❚ Pause', resume: '▶ Resume', cancel: '✕ Cancel',
      extConnected: 'Extension connected', extNotConnected: 'Extension not connected — install it and keep SnapDL running',
      adblockOn: 'ON — ads are being blocked in your browser', adblockOff: 'OFF — ads are not blocked',
      confirmDelete: 'Delete "{t}" from history?\n\nOK = also delete the file from disk.\nCancel = remove from history only.',
      confirmClearLog: 'Clear the diagnostics log?',
      jobFailed: 'Download failed: ',
      jobFailedHint: ' — check the diagnostics log for the exact reason.',
      updateChecking: 'Checking for updates…', updateWait: 'Contacting the update server, please wait.',
      updateAvailable: 'Update available — v', updateReady: 'A newer version of SnapDL is ready.',
      updateLatest: 'You are up to date', updateLatestBody: 'SnapDL v{version} is the latest version.',
      updateFail: 'Could not check for updates', updateDownload: 'Download update ↗', close: 'Close',
      updates_update_now: 'Update Now', updates_update_tonight: 'Update Tonight',
      updates_tonight_scheduled: 'Update scheduled for tonight.',
      updates_downloading: 'Downloading update…', updates_install_now: 'Install Now',
      updates_install_later: 'Install Later',
      updates_install_later_saved: 'Update saved — you can install it later from Settings → Updates.',
      updates_download_failed: 'Update download failed.',
      updates_size: 'Size', updates_features: "What's new",
      speedtest_title: 'Internet Speed Test',
      speedtest_note: 'Measure your download, upload, ping and jitter — the test only starts when you tap Start.',
      speedtest_start: '▶ Start test', speedtest_again: '↻ Measure again',
      speedtest_measuring: 'Measuring…', speedtest_download: 'Download', speedtest_upload: 'Upload',
      speedtest_ping: 'Ping', speedtest_jitter: 'Jitter',
      speedtest_failed: 'Speed test failed.', speedtest_retry: 'Retry',
      speedtest_unit_mbps: 'Mbps', speedtest_unit_mbs: 'MB/s',
      speedtest_datanote: 'Uses about 12 MB of data per test.',
      previewLoading: 'Fetching video info…', previewPlay: 'Play preview',
      fetchErrorLink: 'Could not read this link.', fetchErrorGeneric: 'Something went wrong: ',
      uploaderBy: 'by {name}', durationLabel: 'Duration {d}',
      platformVideo: 'Video', platformFile: 'File',
      histOpen: 'Open', histAgain: 'Again', histDelete: 'Delete', histCount: '{n} items',
      toastRedownloading: 'Re-downloading…', toastFileNotFound: 'File not found.',
      toastRedownloadFail: 'Could not re-download.', toastDeleteFail: 'Could not delete.',
      toastStartFail: 'Could not start the download.', logEmpty: 'No log entries yet.',
      aboutVersion: 'Version {v} · Windows',
      qLabelHighest: 'Highest quality', qLabel4k: '4K (2160p)', qLabel1080: '1080p Full HD',
      qLabel720: '720p HD', qLabelLowest: 'Lowest quality', qLabelAudio: 'Audio only (MP3)',
      qLabelFile: 'Original file'
    },
    ar: {
      brandSub: 'منزّل الفيديو', navDownload: 'التنزيل', navYoutube: 'يوتيوب', navHistory: 'السجل', navSpeed: 'سرعة الإنترنت', navSettings: 'الإعدادات',
      checkUpdates: 'التحقق من التحديثات',
      dlTitle1: 'الصق رابطًا.', dlTitle2: 'واحصل على الفيديو.',
      dlSub: 'يوتيوب · تيك توك · إنستجرام · فيسبوك · إكس — مجاني، بدون إعلانات، بدون تسجيل دخول.',
      videoLink: 'رابط الفيديو', urlPlaceholder: 'https://www.youtube.com/watch?v=… أو رابط تيك توك / إنستجرام / فيسبوك / إكس',
      getInfo: 'جلب المعلومات', quality: 'الجودة', qHighest: 'الأعلى', qHighestSub: 'أفضل جودة متاحة', qFullHD: 'Full HD',
      qLowest: 'الأقل', qLowestSub: 'أصغر حجم', qAudio: 'صوت فقط',
      saveTo: 'الحفظ في', change: 'تغيير', download: 'تنزيل',
      browserTitle: 'التكامل مع المتصفح — مثل IDM',
      browserSub: 'ثبّت إضافة SnapDL في Edge أو Chrome وسيظهر زر «تنزيل الفيديو» فوق أي فيديو يعمل في المتصفح. واضغط بزر الفأرة الأيمن على أي رابط أو صورة ← «تنزيل بواسطة SnapDL». يجب أن يكون التطبيق يعمل حتى يعمل الزر.',
      openExtFolder: 'فتح مجلد الإضافة',
      ytInApp: 'داخل SnapDL',
      ytSub: 'شاهد يوتيوب داخل التطبيق. تظهر الإعلانات بشكل طبيعي. استخدم الزر بالأسفل لتنزيل الفيديو الذي تشاهده.',
      ytDownloadBtn: 'تنزيل هذا الفيديو',
      ytNote: 'ملاحظة: تسجيل الدخول إلى جوجل داخل التطبيق غير مضمون — قد تحظر جوجل تسجيل الدخول في النوافذ المضمّنة. إذا لم يعمل، سجّل الدخول من Edge أو Chrome. التنزيلات تعمل بدون تسجيل دخول.',
      histTitle1: 'سجل', histTitle2: 'التنزيلات',
      histSub: 'كل ما نزّلته، محفوظ على جهازك فقط.',
      openFolder: 'فتح مجلد التنزيلات', histEmpty1: 'لا توجد تنزيلات بعد.',
      histEmpty2: 'الصق رابطًا في صفحة التنزيل وسيظهر سجلك هنا.',
      settingsTitle: 'الإعدادات', settingsSub: 'اضغط على أي صف لفتح شاشته الخاصة.',
      setAppearance: 'المظهر', setAppearanceSub: 'داكن · فاتح · حسب النظام',
      setLanguage: 'اللغة', setDownloads: 'التنزيلات', setDownloadsSub: 'المجلد · الجودة الافتراضية · واي فاي فقط',
      setAdblock: 'مانع الإعلانات', setAdblockSub: 'حظر الإعلانات في المتصفح',
      setExtension: 'إضافة المتصفح', setUpdates: 'التحديثات', setUpdatesSub: 'التحقق من وجود نسخة جديدة',
      setLogs: 'سجل التشخيص', setLogsSub: 'كل الأحداث، مع السبب الدقيق عند حدوث خطأ',
      setAbout: 'حول التطبيق', back: 'رجوع',
      appearanceDesc: 'اختر شكل SnapDL. يُطبَّق فورًا.',
      themeDark: 'داكن', themeDarkSub: 'زجاج داكن مريح للعين ليلًا',
      themeLight: 'فاتح', themeLightSub: 'فاتح ونظيف',
      themeSystem: 'حسب النظام', themeSystemSub: 'يطابق الوضع الفاتح / الداكن في ويندوز',
      languageDesc: 'يُطبَّق فورًا.',
      defaultQuality: 'الجودة الافتراضية',
      wifiOnly: 'واي فاي فقط', wifiOnlySub: 'التنزيل فقط عند الاتصال بشبكة واي فاي',
      maxConc: 'أقصى عدد للتنزيلات المتزامنة', maxConcSub: 'عدد التنزيلات التي تعمل في نفس الوقت',
      adblockDesc: 'يحظر الإعلانات داخل Edge وChrome باستخدام إضافة SnapDL (قواعد EasyList). داخل المتصفح فقط — وليس على مستوى النظام.',
      adblockToggle: 'مانع الإعلانات', adblockBlocked: 'الإعلانات المحظورة', adblockRules: 'قواعد الفلترة',
      adblockNote: 'إعلانات فيديو يوتيوب لا تُحظر — لأنها تأتي من نفس نطاق الفيديو. نزّل الفيديو بـ SnapDL بدلًا من ذلك.',
      extStatus: 'الحالة', extServer: 'الخادم المحلي',
      extGuide: 'ثبّتها مرة واحدة — تحميل غير مضغوط في وضع المطوّر:\nEdge ← edge://extensions ← وضع المطوّر ← تحميل غير مضغوط ← اختر مجلد الإضافة.\nChrome ← chrome://extensions ← نفس الخطوات.\nيجب أن يعمل تطبيق SnapDL حتى يعمل زر الفيديو.',
      updCurrent: 'النسخة الحالية', autoCheck: 'التحقق تلقائيًا',
      autoCheckSub: 'التحقق من وجود نسخة جديدة عند تشغيل SnapDL',
      logsDesc: 'كل الأحداث، مع السبب الدقيق عند حدوث خطأ. بهذه الطريقة نكتشف الأخطاء بسرعة.',
      logAll: 'كل الفئات', logErrors: 'الأخطاء فقط', copyLog: 'نسخ السجل', clearLog: 'مسح السجل',
      aboutDesc: 'منزّل سريع وجميل ليوتيوب وتيك توك وإنستجرام وفيسبوك وإكس. الصق رابطًا، اختر الجودة، والفيديو أصبح لك — بدون إعلانات وبدون حسابات وبدون علامات مائية.',
      aboutDev: 'المطوّر', aboutPlatform: 'المنصة',
      viewPortfolio: 'عرض أعمالي ↗',
      toastPasteFirst: 'الصق رابط فيديو أولًا.', toastFolderUpdated: 'تم تحديث مجلد التنزيل.',
      toastLogCopied: 'تم نسخ السجل.', toastFinished: 'اكتمل التنزيل: ',
      toastQueued: 'في الانتظار — سيبدأ عند توفر مكان.',
      toastNoVideo: 'افتح فيديو يوتيوب أولًا ثم اضغط تنزيل.',
      toastExtMissing: 'مجلد الإضافة غير موجود.',
      phaseStarting: 'جارٍ البدء…', phaseDownloading: 'جارٍ التنزيل…', phaseMerging: 'جارٍ دمج الفيديو والصوت…',
      phaseConverting: 'جارٍ التحويل…', phaseFinishing: 'جارٍ الإنهاء…', phaseQueued: 'في انتظار مكان فارغ…',
      phasePaused: 'متوقف مؤقتًا — تقدّمك محفوظ، استأنف في أي وقت.',
      speed: 'السرعة', eta: 'الوقت المتبقي', size: 'الحجم',
      pause: '❚❚ إيقاف مؤقت', resume: '▶ استئناف', cancel: '✕ إلغاء',
      extConnected: 'الإضافة متصلة', extNotConnected: 'الإضافة غير متصلة — ثبّتها وأبقِ SnapDL يعمل',
      adblockOn: 'يعمل — يتم حظر الإعلانات في متصفحك', adblockOff: 'متوقف — الإعلانات غير محظورة',
      confirmDelete: 'حذف "{t}" من السجل؟\n\nموافق = حذف الملف من القرص أيضًا.\nإلغاء = الحذف من السجل فقط.',
      confirmClearLog: 'مسح سجل التشخيص؟',
      jobFailed: 'فشل التنزيل: ',
      jobFailedHint: ' — راجع سجل التشخيص لمعرفة السبب الدقيق.',
      updateChecking: 'جارٍ التحقق من التحديثات…', updateWait: 'جارٍ الاتصال بخادم التحديثات، انتظر قليلًا.',
      updateAvailable: 'يوجد تحديث — الإصدار ', updateReady: 'نسخة أحدث من SnapDL جاهزة.',
      updateLatest: 'أنت على أحدث نسخة', updateLatestBody: 'SnapDL الإصدار {version} هو الأحدث.',
      updateFail: 'تعذّر التحقق من التحديثات', updateDownload: 'تنزيل التحديث ↗', close: 'إغلاق',
      updates_update_now: 'التحديث الآن', updates_update_tonight: 'التحديث الليلة',
      updates_tonight_scheduled: 'تمت جدولة التحديث الليلة.',
      updates_downloading: 'جارٍ تنزيل التحديث…', updates_install_now: 'التثبيت الآن',
      updates_install_later: 'التثبيت لاحقًا',
      updates_install_later_saved: 'تم حفظ التحديث — يمكنك تثبيته لاحقًا من الإعدادات ← التحديثات.',
      updates_download_failed: 'فشل تنزيل التحديث.',
      updates_size: 'الحجم', updates_features: 'المزايا الجديدة',
      speedtest_title: 'اختبار سرعة الإنترنت',
      speedtest_note: 'قِس سرعة التنزيل والرفع والبينج والتذبذب — لا يبدأ الاختبار إلا عند الضغط على «ابدأ».',
      speedtest_start: '▶ ابدأ الاختبار', speedtest_again: '↻ قياس مرة أخرى',
      speedtest_measuring: 'جارٍ القياس…', speedtest_download: 'التنزيل', speedtest_upload: 'الرفع',
      speedtest_ping: 'البينج', speedtest_jitter: 'التذبذب',
      speedtest_failed: 'فشل اختبار السرعة.', speedtest_retry: 'إعادة المحاولة',
      speedtest_unit_mbps: 'Mbps', speedtest_unit_mbs: 'MB/s',
      speedtest_datanote: 'يستهلك الاختبار حوالي 12 م.ب. من البيانات.',
      previewLoading: 'جارٍ جلب معلومات الفيديو…', previewPlay: 'تشغيل المعاينة',
      fetchErrorLink: 'تعذّر قراءة هذا الرابط.', fetchErrorGeneric: 'حدث خطأ: ',
      uploaderBy: 'بواسطة {name}', durationLabel: 'المدة {d}',
      platformVideo: 'فيديو', platformFile: 'ملف',
      histOpen: 'فتح', histAgain: 'إعادة التنزيل', histDelete: 'حذف', histCount: 'عدد العناصر: {n}',
      toastRedownloading: 'جارٍ إعادة التنزيل…', toastFileNotFound: 'الملف غير موجود.',
      toastRedownloadFail: 'تعذّرت إعادة التنزيل.', toastDeleteFail: 'تعذّر الحذف.',
      toastStartFail: 'تعذّر بدء التنزيل.', logEmpty: 'لا توجد مدخلات في السجل بعد.',
      aboutVersion: 'الإصدار {v} · ويندوز',
      qLabelHighest: 'أعلى جودة', qLabel4k: '4K (2160p)', qLabel1080: '1080p Full HD',
      qLabel720: '720p HD', qLabelLowest: 'أقل جودة', qLabelAudio: 'صوت فقط (MP3)',
      qLabelFile: 'الملف الأصلي'
    }
  };
  let lang = 'ar';
  function t(key, vars) {
    let s = (I18N[lang] && I18N[lang][key]) || I18N.en[key] || key;
    if (vars) for (const k of Object.keys(vars)) s = s.replace('{' + k + '}', vars[k]);
    return s;
  }
  function applyI18n() {
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
    document.querySelectorAll('[data-i18n]').forEach(el => { el.textContent = t(el.dataset.i18n); });
    document.querySelectorAll('[data-i18n-ph]').forEach(el => { el.placeholder = t(el.dataset.i18nPh); });
    document.querySelectorAll('[data-i18n-title]').forEach(el => { el.title = t(el.dataset.i18nTitle); });
  }

  // ================= mock API (plain browser render) =================
  const MOCK = {
    appInfo: async () => ({ name: 'SnapDL', version: '1.0.0', portfolioUrl: 'https://mohamed5946.github.io/portfolio/', releasesUrl: 'https://github.com/mohamed5946/video-downloader/releases/latest', downloadDir: 'C:\\Users\\DELL\\Downloads\\SnapDL', adblock: true, adblockBlocked: 128 }),
    getSettings: async () => ({ theme: 'light', language: 'ar', defaultQuality: 'highest', wifiOnly: false, maxConcurrent: 1, adblock: true, adblockBlocked: 128, autoCheck: false, speedUnit: 'Mbps', updateTonight: false, pendingUpdatePath: '', downloadDir: 'C:\\Users\\DELL\\Downloads\\SnapDL' }),
    setSetting: async () => ({ ok: true }),
    getAdblockState: async () => ({ enabled: true, blocked: 128, extensionConnected: true, extVersion: '1.0.0' }),
    chooseFolder: async () => null,
    fetchInfo: async () => ({ ok: true, title: 'Big Buck Bunny — 4K 60fps Official Trailer (Sample)', platform: 'YouTube', duration: 596, maxHeight: 2160, uploader: 'Blender Foundation', thumbnail: 'sample-thumb.png' }),
    startDownload: async () => ({ ok: true, jobId: 1 }),
    pauseDownload: async () => ({ ok: true }),
    resumeDownload: async () => ({ ok: true }),
    cancelDownload: async () => ({ ok: true }),
    getHistory: async () => [],
    openFile: async () => ({ ok: true }),
    openFolder: async () => ({ ok: true }),
    deleteHistory: async () => ({ ok: true }),
    redownload: async () => ({ ok: true }),
    getLogs: async () => [],
    clearLogs: async () => ({ ok: true }),
    copyLogs: async () => ({ ok: true }),
    checkUpdates: async () => ({ ok: true, update: false, version: '1.0.0' }),
    runSpeedTest: async () => ({ ok: true, downloadMbps: 94.5, uploadMbps: 32.1, pingMs: 40, jitterMs: 31 }),
    cancelSpeedTest: async () => ({ ok: true }),
    onSpeedTestSample: () => {},
    downloadUpdate: async () => ({ ok: true, path: 'C:\\Downloads\\SnapDL-update.zip', size: 260789130 }),
    downloadAppUpdate: async () => ({ ok: true, path: '__updater__', size: 0 }),
    onUpdateDownloadProgress: () => {},
    installUpdate: async () => ({ ok: true }),
    setUpdateTonight: async () => ({ ok: true }),
    openExternal: async () => ({ ok: true }),
    openExtensionFolder: async () => ({ ok: true }),
    onDownloadList: () => {}, onHistoryUpdated: () => {}, onLogAdded: () => {}, onSettingsChanged: () => {},
    onPreviewState: (cb) => { window.__previewStateCb = cb; },
    onPreviewShowView: (cb) => { window.__previewShowViewCb = cb; },
    onPreviewShowSub: (cb) => { window.__previewShowSubCb = cb; }
  };
  const api = (window.snapdlAPI && window.snapdlAPI.appInfo) ? window.snapdlAPI : MOCK;
  const IS_MOCK = api === MOCK;

  // ================= state =================
  let settings = { theme: 'light', language: 'ar', defaultQuality: 'highest', wifiOnly: false, maxConcurrent: 1, adblock: true, adblockBlocked: 0, autoCheck: false, speedUnit: 'Mbps', updateTonight: false, pendingUpdatePath: '' };
  let selectedQuality = 'highest';
  let currentInfo = null;
  let activeJobs = [];
  let history = [];
  let logs = [];
  let logFilter = 'all';
  let appInfo = null;

  // ================= helpers =================
  function fmtDuration(sec) {
    if (!sec) return '';
    const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = Math.floor(sec % 60);
    return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}` : `${m}:${String(s).padStart(2, '0')}`;
  }
  function fmtSize(bytes) {
    if (bytes == null) return '—';
    const u = ['B', 'KB', 'MB', 'GB']; let i = 0, n = bytes;
    while (n >= 1024 && i < u.length - 1) { n /= 1024; i++; }
    return (n >= 100 ? Math.round(n) : n.toFixed(1)) + ' ' + u[i];
  }
  function fmtDate(iso) { try { return new Date(iso).toLocaleString(lang === 'ar' ? 'ar-EG' : 'en-US'); } catch (_) { return iso || ''; } }
  function fmtTime(iso) { try { return new Date(iso).toLocaleTimeString(lang === 'ar' ? 'ar-EG' : 'en-US', { hour: '2-digit', minute: '2-digit', second: '2-digit' }); } catch (_) { return ''; } }
  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }

  let toastTimer = null;
  function toast(msg) {
    const el = $('toast');
    el.textContent = msg;
    el.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.remove('show'), 3200);
  }

  // ================= staggered entrance (DeliveryFlow rule) =================
  // EVERY list in the app staggers in — fade + slide, 80ms per item, capped
  // at index 7 (560ms max delay), 300ms per item, ease-out — mirroring
  // DeliveryFlow's StaggeredItem (df-v23-work/lib/theme/staggered_entrance.dart).
  // Items below the fold animate as they scroll into view (IntersectionObserver);
  // once seen, an item never re-animates on refresh or scroll-back. A view
  // re-open replays the stagger (same as DeliveryFlow's TabReplayScope).
  const STAGGER_CAP = 7;
  const staggerSeen = new Set();
  let staggerObserver = null;
  function staggerObserverInit() {
    if (staggerObserver) return staggerObserver;
    staggerObserver = new IntersectionObserver(entries => {
      for (const en of entries) {
        if (!en.isIntersecting) continue;
        const el = en.target;
        staggerObserver.unobserve(el);
        el.classList.add('stagger-in');
        if (el.dataset.staggerKey) staggerSeen.add(el.dataset.staggerKey);
      }
    }, { threshold: 0.05, rootMargin: '0px 0px -4px 0px' });
    return staggerObserver;
  }
  function logRowKey(el) {
    const t = (el.querySelector('.log-time') || {}).textContent || '';
    const c = (el.querySelector('.log-cat') || {}).textContent || '';
    const m = (el.querySelector('.log-msg') || {}).textContent || '';
    return 'log:' + t + '|' + c + '|' + m.slice(0, 40);
  }
  function applyStagger(container, selector, keyFn) {
    if (!container) return;
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const obs = staggerObserverInit();
    container.querySelectorAll(selector).forEach((el, i) => {
      const key = keyFn ? keyFn(el, i) : null;
      if (key) el.dataset.staggerKey = key;
      if (key && staggerSeen.has(key)) {
        // Already played: appear immediately, never re-animate.
        el.classList.add('stagger-item', 'stagger-seen');
        el.classList.remove('stagger-in');
        return;
      }
      el.classList.add('stagger-item');
      el.classList.remove('stagger-in', 'stagger-seen');
      el.style.setProperty('--stagger-i', Math.min(i, STAGGER_CAP));
      if (reduced) {
        el.classList.add('stagger-seen');
        if (key) staggerSeen.add(key);
        return;
      }
      obs.observe(el);
    });
  }
  function forgetStaggerKeys(prefix) {
    for (const k of Array.from(staggerSeen)) if (k.startsWith(prefix)) staggerSeen.delete(k);
  }
  // [container selector, item selector, key factory, seen-key prefix]
  const STAGGER_LISTS = [
    ['#jobsList', '.job-card', el => 'job:' + el.dataset.jobId, 'job:'],
    ['#historyList', '.history-item', el => 'hist:' + el.dataset.id, 'hist:'],
    ['#logList', '.log-row', logRowKey, 'log:'],
    ['.settings-list', '.setting-row', (el, i) => 'set:' + i, 'set:'],
    ['.option-list', '.option-card', (el, i) => 'opt:' + (el.closest('.sub-screen') ? el.closest('.sub-screen').id : 'main') + ':' + i, 'opt:'],
    ['#qualityGrid', '.quality-pill', (el, i) => 'q:' + i, 'q:'],
    ['#dlQualityGrid', '.quality-pill', (el, i) => 'dq:' + i, 'dq:'],
    ['.about-rows', '.about-row', (el, i) => 'about:' + i, 'about:'],
    ['.sub-card', '.stat-row', (el, i) => 'stat:' + (el.closest('.sub-screen') ? el.closest('.sub-screen').id : 'main') + ':' + i, 'stat:'],
    ['.sub-card', '.switch-row', (el, i) => 'sw:' + (el.closest('.sub-screen') ? el.closest('.sub-screen').id : 'main') + ':' + i, 'sw:']
  ];
  function applyAllStagger(root) {
    const scope = root || document;
    for (const [sel, itemSel, keyFn] of STAGGER_LISTS) {
      scope.querySelectorAll(sel).forEach(c => applyStagger(c, itemSel, keyFn));
    }
  }
  function replayStagger() {
    // View re-open: every list replays its entrance from the top.
    for (const entry of STAGGER_LISTS) forgetStaggerKeys(entry[3]);
    document.querySelectorAll('.stagger-item').forEach(el => el.classList.remove('stagger-in', 'stagger-seen'));
    applyAllStagger(document);
  }

  // ================= theme =================
  function applyTheme() {
    let theme = settings.theme || 'dark';
    if (theme === 'system') theme = window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
    document.documentElement.dataset.theme = theme;
    document.querySelectorAll('[data-theme-opt]').forEach(b => b.classList.toggle('selected', b.dataset.themeOpt === settings.theme));
  }
  window.matchMedia('(prefers-color-scheme: light)').addEventListener('change', () => { if (settings.theme === 'system') applyTheme(); });

  // ================= views & sub-screens =================
  function closeSubScreens() {
    document.querySelectorAll('.sub-screen').forEach(s => s.classList.add('hidden'));
    $('settingsList').classList.remove('hidden');
  }
  function showView(name) {
    closeSubScreens();
    document.querySelectorAll('.nav-btn').forEach(b => b.classList.toggle('active', b.dataset.view === name));
    document.querySelectorAll('.view').forEach(v => v.classList.toggle('active', v.id === 'view-' + name));
    if (name === 'history') renderHistory();
    if (name === 'settings') closeSubScreens();
    replayStagger();
  }
  function openSubScreen(name) {
    showView('settings');
    $('settingsList').classList.add('hidden');
    document.querySelectorAll('.sub-screen').forEach(s => s.classList.add('hidden'));
    const el = $('sub-' + name);
    if (el) el.classList.remove('hidden');
    if (name === 'logs') renderLogs();
    if (name === 'adblock') refreshAdblockScreen();
    if (name === 'extension') refreshExtensionScreen();
    if (name === 'updates') refreshUpdatesScreen();
  }
  document.querySelectorAll('.nav-btn').forEach(b => b.addEventListener('click', () => showView(b.dataset.view)));
  document.querySelectorAll('.setting-row').forEach(b => b.addEventListener('click', () => openSubScreen(b.dataset.setting)));
  document.querySelectorAll('.sub-back').forEach(b => b.addEventListener('click', () => { closeSubScreens(); replayStagger(); }));

  // ================= quality pickers =================
  function qualityLabel(key) {
    const map = { highest: 'qLabelHighest', '4k': 'qLabel4k', '1080p': 'qLabel1080', '720p': 'qLabel720', lowest: 'qLabelLowest', audio: 'qLabelAudio', file: 'qLabelFile' };
    return map[key] ? t(map[key]) : (key || '');
  }
  function platformLabel(p) {
    if (!p) return t('platformVideo');
    if (p === 'File') return t('platformFile');
    return p;
  }
  function markQuality(gridId, value) {
    document.querySelectorAll('#' + gridId + ' .quality-pill').forEach(x => x.classList.toggle('selected', x.dataset.quality === value));
  }
  document.querySelectorAll('#qualityGrid .quality-pill').forEach(p => {
    p.addEventListener('click', () => {
      if (p.classList.contains('disabled')) return;
      markQuality('qualityGrid', p.dataset.quality);
      selectedQuality = p.dataset.quality;
    });
  });
  document.querySelectorAll('#dlQualityGrid .quality-pill').forEach(p => {
    p.addEventListener('click', async () => {
      markQuality('dlQualityGrid', p.dataset.quality);
      await api.setSetting('defaultQuality', p.dataset.quality);
      settings.defaultQuality = p.dataset.quality;
      selectedQuality = p.dataset.quality;
      markQuality('qualityGrid', p.dataset.quality);
    });
  });
  function applyMaxHeight(maxH) {
    const limits = { '4k': 2160, '1080p': 1080, '720p': 720 };
    document.querySelectorAll('#qualityGrid .quality-pill').forEach(p => {
      const lim = limits[p.dataset.quality];
      p.classList.toggle('disabled', !!lim && !!maxH && maxH < lim);
    });
    if (limits[selectedQuality] && maxH && maxH < limits[selectedQuality]) {
      selectedQuality = 'highest';
      markQuality('qualityGrid', 'highest');
    }
  }

  // ================= fetch info =================
  function fillPreview(res, url) {
    $('infoTitle').textContent = res.title || '';
    $('infoPlatform').textContent = platformLabel(res.platform);
    $('infoUploader').textContent = res.uploader ? t('uploaderBy', { name: res.uploader }) : '';
    $('infoDuration').textContent = res.duration ? fmtDuration(res.duration) : '';
    const thumb = $('previewThumb');
    if (res.thumbnail) { thumb.src = res.thumbnail; thumb.style.display = ''; }
    else thumb.style.display = 'none';
    currentInfo = Object.assign({}, res, { url: url || (currentInfo && currentInfo.url) || $('urlInput').value.trim() });
    renderPreviewQuality();
  }
  function renderPreviewQuality() {
    const wrap = $('previewQuality');
    if (!wrap) return;
    const opts = ['highest', '1080p', '720p', 'audio'];
    const labels = { highest: t('qHighest'), '1080p': '1080p', '720p': '720p', audio: t('qAudio') };
    wrap.innerHTML = opts.map(q => `<button class="chip q-chip${selectedQuality === q ? ' selected' : ''}" data-q="${q}">${esc(labels[q])}</button>`).join('');
    wrap.querySelectorAll('.q-chip').forEach(c => c.addEventListener('click', () => {
      selectedQuality = c.dataset.q;
      markQuality('qualityGrid', selectedQuality);
      renderPreviewQuality();
    }));
  }
  async function fetchInfo() {
    const url = $('urlInput').value.trim();
    if (!url) { toast(t('toastPasteFirst')); return; }
    const card = $('previewCard');
    const loading = $('previewLoading');
    const body = $('previewBody');
    $('fetchError').classList.add('hidden');
    card.classList.remove('hidden');
    body.classList.add('hidden');
    loading.classList.remove('hidden');
    const btn = $('fetchInfoBtn');
    btn.disabled = true; btn.textContent = '…';
    try {
      const res = await api.fetchInfo(url);
      if (!res.ok) {
        card.classList.add('hidden');
        const e = $('fetchError');
        e.textContent = res.error || t('fetchErrorLink');
        e.classList.remove('hidden');
        return;
      }
      fillPreview(res, url);
      loading.classList.add('hidden');
      body.classList.remove('hidden');
      if (res.maxHeight) applyMaxHeight(res.maxHeight);
    } catch (e) {
      card.classList.add('hidden');
      const el = $('fetchError');
      el.textContent = t('fetchErrorGeneric') + e.message;
      el.classList.remove('hidden');
    } finally {
      btn.disabled = false; btn.textContent = t('getInfo');
    }
  }
  $('fetchInfoBtn').addEventListener('click', fetchInfo);
  $('urlInput').addEventListener('keydown', e => { if (e.key === 'Enter') fetchInfo(); });
  // Pasting a link fetches its preview automatically — no extra click needed.
  $('urlInput').addEventListener('paste', () => {
    setTimeout(() => {
      const v = $('urlInput').value.trim();
      if (/^https?:\/\//i.test(v)) fetchInfo();
    }, 60);
  });
  // Optional inline play: preview the video in the in-app YouTube tab.
  $('previewPlayBtn').addEventListener('click', () => {
    const url = (currentInfo && currentInfo.url) || $('urlInput').value.trim();
    if (!url) return;
    if (isWebview) {
      try { ytView.loadURL(url); } catch (_) {}
      showView('youtube');
    } else {
      api.openExternal(url);
    }
  });

  // ================= download folder =================
  async function refreshFolder() {
    try {
      const s = await api.getSettings();
      $('folderPath').textContent = s.downloadDir || '—';
      const dl = $('dlFolderPath');
      if (dl) dl.textContent = s.downloadDir || '—';
    } catch (_) {}
  }
  async function pickFolder() {
    const dir = await api.chooseFolder();
    if (dir) {
      $('folderPath').textContent = dir;
      const dl = $('dlFolderPath');
      if (dl) dl.textContent = dir;
      toast(t('toastFolderUpdated'));
    }
  }
  $('changeFolderBtn').addEventListener('click', pickFolder);
  $('dlChangeFolderBtn').addEventListener('click', pickFolder);
  $('openFolderBtn').addEventListener('click', () => api.openFolder(null));

  // ================= downloads =================
  $('downloadBtn').addEventListener('click', async () => {
    const url = $('urlInput').value.trim();
    if (!url) { toast(t('toastPasteFirst')); return; }
    const btn = $('downloadBtn');
    btn.disabled = true;
    // v1.0.8: pass the fetched video info so the history card can
    // render like the preview card — but only when the info belongs to
    // THIS link (a stale preview from an earlier link must not attach
    // its thumbnail/title to the new download).
    const info = (currentInfo && currentInfo.url === url) ? currentInfo : null;
    const res = await api.startDownload({
      url, quality: selectedQuality,
      title: (info && info.title) || '', platform: (info && info.platform) || '',
      thumbnail: (info && info.thumbnail) || null, duration: (info && info.duration) || null
    });
    btn.disabled = false;
    if (!res.ok) toast(res.error || t('toastStartFail'));
    else if (res.queued) toast(t('toastQueued'));
  });

  function jobCardHtml(job) {
    const pct = Math.max(0, Math.min(100, job.progress || 0));
    const phaseKey = { starting: 'phaseStarting', downloading: 'phaseDownloading', merging: 'phaseMerging', converting: 'phaseConverting', finishing: 'phaseFinishing', queued: 'phaseQueued', paused: 'phasePaused' };
    const phaseText = job.statusText || t(phaseKey[job.phase] || (job.status === 'paused' ? 'phasePaused' : job.status === 'queued' ? 'phaseQueued' : 'phaseDownloading'));
    const showPause = job.status === 'downloading';
    const showResume = job.status === 'paused';
    const showCancel = job.status === 'downloading' || job.status === 'paused' || job.status === 'queued';
    return `
    <div class="glass card job-card" data-job-id="${job.id}">
      <div class="job-head">
        <div>
          <div class="job-title">${esc(job.title || job.url || '…')}</div>
          <div class="job-sub"><span class="badge">${esc(platformLabel(job.platform))}</span><span class="badge badge-quality">${esc(qualityLabel(job.quality))}</span><span class="job-phase">${esc(phaseText)}</span></div>
        </div>
        <div class="job-pct">${Math.floor(pct)}%</div>
      </div>
      <div class="progress-track"><div class="progress-fill" style="width:${pct}%"></div></div>
      <div class="job-stats">
        <span><b>${esc(job.speed || (job.status === 'paused' ? '—' : '—'))}</b><i>${t('speed')}</i></span>
        <span><b>${esc(job.eta || '—')}</b><i>${t('eta')}</i></span>
        <span><b>${esc(job.sizeTotal || (job.size ? fmtSize(job.size) : '—'))}</b><i>${t('size')}</i></span>
      </div>
      ${job.status === 'error' ? `<div class="error-box">${esc(t('jobFailed') + (job.error || 'unknown error') + t('jobFailedHint'))}</div>` : ''}
      <div class="job-actions">
        ${showPause ? `<button class="glass-btn" data-act="pause">${t('pause')}</button>` : ''}
        ${showResume ? `<button class="glass-btn" data-act="resume">${t('resume')}</button>` : ''}
        ${showCancel ? `<button class="btn-danger-ghost" data-act="cancel">${t('cancel')}</button>` : ''}
      </div>
    </div>`;
  }
  function renderJobs(list) {
    const prevDone = activeJobs.filter(j => j.status === 'done').map(j => j.id);
    activeJobs = list || [];
    const container = $('jobsList');
    const visible = activeJobs.filter(j => j.status !== 'done' && j.status !== 'cancelled');
    container.innerHTML = visible.map(jobCardHtml).join('');
    container.querySelectorAll('.job-card').forEach(card => {
      const id = Number(card.dataset.jobId);
      const pause = card.querySelector('[data-act="pause"]');
      const resume = card.querySelector('[data-act="resume"]');
      const cancel = card.querySelector('[data-act="cancel"]');
      if (pause) pause.addEventListener('click', async () => { const r = await api.pauseDownload(id); if (!r.ok) toast(r.error || ''); });
      if (resume) resume.addEventListener('click', async () => { const r = await api.resumeDownload(id); if (!r.ok) toast(r.error || ''); });
      if (cancel) cancel.addEventListener('click', async () => { const r = await api.cancelDownload(id); if (!r.ok) toast(r.error || ''); });
    });
    activeJobs.filter(j => j.status === 'done' && !prevDone.includes(j.id)).forEach(j => toast(t('toastFinished') + (j.title || 'video')));
    applyStagger(container, '.job-card', el => 'job:' + el.dataset.jobId);
  }
  api.onDownloadList(list => renderJobs(list));

  // ================= history =================
  function renderHistory() {
    const list = $('historyList');
    const empty = $('historyEmpty');
    $('historyCount').textContent = history.length ? String(history.length) : '';
    $('historyCountLabel').textContent = history.length ? t('histCount', { n: history.length }) : '';
    if (!history.length) { list.innerHTML = ''; empty.classList.remove('hidden'); return; }
    empty.classList.add('hidden');
    // v1.0.8: each history item looks like the Download-page preview
    // card — same .preview-thumb (thumbnail + play overlay + duration)
    // and .preview-info (title, platform badge, quality, size, date),
    // with the existing فتح / إعادة التنزيل / حذف buttons below the
    // details. Entries without a stored thumbnail (older downloads,
    // extension / watch-tab jobs) show a placeholder, never a broken
    // image. The play overlay opens the file exactly like فتح, through
    // the verified-path Open handler in main.js.
    list.innerHTML = history.map(h => `
      <div class="history-item" data-id="${h.id}">
        <div class="preview-thumb hist-thumb">
          ${h.thumbnail ? `<img src="${esc(h.thumbnail)}" alt="">` : `<div class="hist-thumb-ph"><span>▶</span></div>`}
          <button class="preview-play" data-act="play" title="${esc(t('histOpen'))}">▶</button>
          ${h.duration ? `<span class="preview-duration">${fmtDuration(h.duration)}</span>` : ''}
        </div>
        <div class="preview-info">
          <div class="preview-title">${esc(h.title)}</div>
          <div class="preview-meta"><span class="badge">${esc(platformLabel(h.platform))}</span><span>${esc(qualityLabel(h.quality))}</span><span>${fmtSize(h.size)}</span><span>${fmtDate(h.date)}</span></div>
          <div class="hist-actions">
            <button class="glass-btn" data-act="open">${t('histOpen')}</button>
            <button class="glass-btn" data-act="redownload">↻ ${t('histAgain')}</button>
            <button class="btn-danger-ghost" data-act="delete">${t('histDelete')}</button>
          </div>
        </div>
      </div>`).join('');
    list.querySelectorAll('.history-item').forEach(item => {
      const id = Number(item.dataset.id);
      // Play overlay = Open: the downloaded file in the system default
      // player, via the verified-path handler (same as فتح).
      const openEntry = async () => {
        const h = history.find(x => x.id === id);
        const res = await api.openFile(h && h.path);
        if (!res.ok) toast(res.error || t('toastFileNotFound'));
      };
      item.querySelector('[data-act="play"]').addEventListener('click', openEntry);
      item.querySelector('[data-act="open"]').addEventListener('click', openEntry);
      item.querySelector('[data-act="redownload"]').addEventListener('click', async () => {
        const res = await api.redownload(id);
        if (res.ok) { showView('download'); toast(t('toastRedownloading')); }
        else toast(res.error || t('toastRedownloadFail'));
      });
      item.querySelector('[data-act="delete"]').addEventListener('click', async () => {
        const h = history.find(x => x.id === id);
        const alsoFile = h && h.path ? confirm(t('confirmDelete', { t: h.title })) : true;
        const res = await api.deleteHistory(id, !!alsoFile);
        if (!res.ok) toast(res.error || t('toastDeleteFail'));
      });
    });
    applyStagger(list, '.history-item', el => 'hist:' + el.dataset.id);
  }
  api.onHistoryUpdated(h => { history = h || []; renderHistory(); });

  // ================= logs (سجل التشخيص) =================
  function renderLogs() {
    const list = $('logList');
    const rows = logs.filter(e => logFilter === 'all' ? true : logFilter === 'error' ? e.level === 'error' : e.category === logFilter);
    if (!rows.length) { list.innerHTML = '<div class="log-empty">' + esc(t('logEmpty')) + '</div>'; return; }
    list.innerHTML = rows.slice().reverse().map(e => `
      <div class="log-row ${e.level === 'error' ? 'error' : ''}">
        <span class="log-time">${fmtTime(e.time)}</span>
        <span class="log-cat ${esc(e.category)}">${esc(e.category)}</span>
        <span class="log-msg">${esc(e.message)}</span>
      </div>`).join('');
    applyStagger(list, '.log-row', logRowKey);
  }
  $('logFilter').addEventListener('change', e => { logFilter = e.target.value; renderLogs(); });
  $('copyLogBtn').addEventListener('click', async () => { await api.copyLogs(); toast(t('toastLogCopied')); });
  $('clearLogBtn').addEventListener('click', async () => {
    if (!confirm(t('confirmClearLog'))) return;
    await api.clearLogs();
    logs = []; renderLogs();
  });
  api.onLogAdded(entry => { logs.push(entry); if (logs.length > 500) logs.shift(); if (!$('sub-logs').classList.contains('hidden')) renderLogs(); });

  // ================= settings screens =================
  function markOptions() {
    document.querySelectorAll('[data-theme-opt]').forEach(b => b.classList.toggle('selected', b.dataset.themeOpt === settings.theme));
    document.querySelectorAll('[data-lang-opt]').forEach(b => b.classList.toggle('selected', b.dataset.langOpt === lang));
    markQuality('dlQualityGrid', settings.defaultQuality || 'highest');
    const wt = $('wifiToggle'); if (wt) wt.checked = !!settings.wifiOnly;
    document.querySelectorAll('#maxConcSeg button').forEach(b => b.classList.toggle('selected', Number(b.dataset.max) === (settings.maxConcurrent || 1)));
    const ac = $('autoCheckToggle'); if (ac) ac.checked = !!settings.autoCheck;
  }
  document.querySelectorAll('[data-theme-opt]').forEach(b => b.addEventListener('click', async () => {
    settings.theme = b.dataset.themeOpt;
    await api.setSetting('theme', settings.theme);
    applyTheme();
    markOptions();
  }));
  document.querySelectorAll('[data-lang-opt]').forEach(b => b.addEventListener('click', async () => {
    lang = b.dataset.langOpt;
    await api.setSetting('language', lang);
    applyI18n();
    renderJobs(activeJobs);
    renderHistory();
    renderLogs();
    syncYtLang();
    markOptions();
  }));
  $('wifiToggle').addEventListener('change', async e => {
    settings.wifiOnly = e.target.checked;
    await api.setSetting('wifiOnly', settings.wifiOnly);
  });
  document.querySelectorAll('#maxConcSeg button').forEach(b => b.addEventListener('click', async () => {
    settings.maxConcurrent = Number(b.dataset.max);
    await api.setSetting('maxConcurrent', settings.maxConcurrent);
    markOptions();
  }));
  $('autoCheckToggle').addEventListener('change', async e => {
    settings.autoCheck = e.target.checked;
    await api.setSetting('autoCheck', settings.autoCheck);
  });

  // ---- Ad Blocker screen ----
  async function refreshAdblockScreen() {
    try {
      const st = await api.getAdblockState();
      $('adblockToggle').checked = !!st.enabled;
      $('adblockStatus').textContent = st.enabled ? t('adblockOn') : t('adblockOff');
      $('adblockBlocked').textContent = Number(st.blocked || 0).toLocaleString('en-US');
    } catch (_) {}
  }
  $('adblockToggle').addEventListener('change', async e => {
    settings.adblock = e.target.checked;
    await api.setSetting('adblock', settings.adblock);
    refreshAdblockScreen();
  });

  // ---- Extension screen ----
  async function refreshExtensionScreen() {
    try {
      const st = await api.getAdblockState();
      $('extStatus').textContent = st.extensionConnected
        ? t('extConnected') + (st.extVersion ? ' · v' + st.extVersion : '')
        : t('extNotConnected');
    } catch (_) {}
  }
  function openExtFolder() {
    api.openExtensionFolder().then(res => { if (!res.ok) toast(res.error || t('toastExtMissing')); });
  }
  $('openExtFolderBtn').addEventListener('click', openExtFolder);
  $('openExtFolderBtn2').addEventListener('click', openExtFolder);

  // ---- Updates screen ----
  // The last check result that had an update available, and the last
  // downloaded update package waiting to be installed.
  let latestUpdate = null;
  let pendingUpdate = null;
  let updDownloading = false;

  function refreshUpdatesScreen() {
    if (appInfo) $('updVersion').textContent = 'v' + appInfo.version;
    const ac = $('autoCheckToggle'); if (ac) ac.checked = !!settings.autoCheck;
    if (latestUpdate) renderUpdateCard(latestUpdate);
  }
  function renderUpdateCard(res) {
    const card = $('updCard');
    if (!card) return;
    $('updVersionNew').textContent = 'SnapDL v' + res.version;
    const size = res.sizeBytes || res.winSizeBytes || res.size || null;
    $('updSize').textContent = size ? fmtSize(size) : '—';
    const notes = $('updNotes');
    notes.textContent = res.notes || '';
    notes.style.display = res.notes ? '' : 'none';
    $('updProgressWrap').classList.add('hidden');
    $('updInstallRow').classList.add('hidden');
    $('updUpdateNowBtn').classList.remove('hidden');
    $('updUpdateNowBtn').disabled = false;
    $('updTonightBtn').classList.remove('hidden');
    $('updEmpty').classList.add('hidden');
    card.classList.remove('hidden');
  }
  function setUpdProgress(pct, speedBps, etaSeconds) {
    const p = Math.max(0, Math.min(100, pct || 0));
    $('updPct').textContent = Math.round(p) + '%';
    const fill = $('updProgressFill');
    if (fill) fill.style.width = p + '%';
    $('updSpeed').textContent = speedBps ? fmtSize(speedBps) + '/s' : '—';
    $('updEta').textContent = fmtEta(etaSeconds);
  }
  $('updCheckBtn').addEventListener('click', () => checkUpdates(false));
  $('updUpdateNowBtn').addEventListener('click', async () => {
    const res = latestUpdate;
    if (!res || !res.url || updDownloading) return;
    if (typeof api.downloadUpdate !== 'function') {
      toast(t('updates_download_failed'));
      return;
    }
    updDownloading = true;
    const btn = $('updUpdateNowBtn');
    btn.disabled = true;
    $('updTonightBtn').classList.add('hidden');
    $('updInstallRow').classList.add('hidden');
    $('updProgressWrap').classList.remove('hidden');
    setUpdProgress(0, 0, null);
    try {
      // v1.0.8: installed app — differential update via electron-updater;
      // otherwise the legacy file download. The legacy download keeps
      // the URL's own type in the saved name: an installer URL must be
      // saved as .exe or the system would treat it as a zip (v1.0.7
      // always saved 'SnapDL-update.zip' — that is why the v1.0.8
      // manifest points Windows at a ZIP containing the installer).
      const isExe = /\.exe($|[?#])/i.test(res.url);
      const dl = res.viaUpdater && typeof api.downloadAppUpdate === 'function'
        ? await api.downloadAppUpdate()
        : await api.downloadUpdate({ url: res.url, fileName: isExe ? 'SnapDL-update.exe' : 'SnapDL-update.zip' });
      if (!dl || !dl.ok) {
        toast(t('updates_download_failed') + (dl && dl.error ? ' ' + dl.error : ''));
        $('updProgressWrap').classList.add('hidden');
        $('updTonightBtn').classList.remove('hidden');
        btn.disabled = false;
        return;
      }
      pendingUpdate = dl;
      $('updProgressWrap').classList.add('hidden');
      btn.classList.add('hidden');
      $('updInstallRow').classList.remove('hidden');
    } catch (e) {
      toast(t('updates_download_failed') + ' ' + (e && e.message ? e.message : ''));
      $('updProgressWrap').classList.add('hidden');
      $('updTonightBtn').classList.remove('hidden');
      btn.disabled = false;
    } finally {
      updDownloading = false;
    }
  });
  $('updTonightBtn').addEventListener('click', async () => {
    try {
      if (typeof api.setUpdateTonight === 'function') await api.setUpdateTonight({ value: true });
      await api.setSetting('updateTonight', true);
      settings.updateTonight = true;
      toast(t('updates_tonight_scheduled'));
    } catch (e) {
      toast(t('updateFail'));
    }
  });
  $('updInstallNowBtn').addEventListener('click', async () => {
    if (!pendingUpdate || !pendingUpdate.path) return;
    try {
      const res = await api.installUpdate({ path: pendingUpdate.path });
      if (!res.ok) toast(res.error || t('updateFail'));
    } catch (e) {
      toast(e && e.message ? e.message : t('updateFail'));
    }
  });
  $('updInstallLaterBtn').addEventListener('click', async () => {
    try {
      // v1.0.8: an electron-updater download is staged by the updater
      // itself — there is no file path to remember; a later check
      // re-downloads it differentially.
      if (pendingUpdate && pendingUpdate.path && pendingUpdate.path !== '__updater__') {
        await api.setSetting('pendingUpdatePath', pendingUpdate.path);
        settings.pendingUpdatePath = pendingUpdate.path;
      }
    } catch (_) {}
    $('updInstallRow').classList.add('hidden');
    $('updUpdateNowBtn').classList.remove('hidden');
    $('updUpdateNowBtn').disabled = false;
    $('updTonightBtn').classList.remove('hidden');
    toast(t('updates_install_later_saved'));
  });
  if (typeof api.onUpdateDownloadProgress === 'function') {
    api.onUpdateDownloadProgress(p => {
      if (!p || !updDownloading) return;
      const pct = p.percent != null ? p.percent
        : (p.total ? Math.round((p.received || 0) / p.total * 100) : 0);
      setUpdProgress(pct, p.speedBps, p.etaSeconds);
      // The update manifest carries no file size — fall back to the
      // Content-Length reported by the download itself.
      if (p.total && latestUpdate && !(latestUpdate.sizeBytes || latestUpdate.winSizeBytes)) {
        $('updSize').textContent = fmtSize(p.total);
      }
    });
  }

  api.onSettingsChanged(change => {
    if (!change) return;
    settings[change.key] = change.value;
    if (change.key === 'theme') applyTheme();
    if (change.key === 'language') { lang = change.value; applyI18n(); renderJobs(activeJobs); renderHistory(); renderLogs(); syncYtLang(); }
    if (change.key === 'defaultQuality') { selectedQuality = change.value; markQuality('qualityGrid', change.value); }
    if (change.key === 'adblock') refreshAdblockScreen();
    markOptions();
  });

  // ================= speed test =================
  // Circular gauge, 0–1000 Mbps. The needle is drawn pointing
  // east (right) in the SVG, so rotate(-210deg) lands it at the lower-left
  // and rotate(30deg) at the lower-right — a 240° sweep through the top,
  // like the Speedtest dial. v1.0.8: the marks 0, 5, 10, 50, 100, 200,
  // 500, 750, 1000 sit at EQUAL arc spacing — piecewise-linear between
  // adjacent marks, so mark i is at fraction i/8 and 100 sits at the
  // exact middle / top-center (fraction 0.5).
  let speedUnit = 'Mbps';
  let speedRunning = false;
  let speedRunId = 0;
  let speedLastLiveMbps = 0;
  let speedHasResult = false;

  const GAUGE_MARKS = [0, 5, 10, 50, 100, 200, 500, 750, 1000];
  function gaugeFraction(mbps) {
    const v = Math.max(0, mbps || 0);
    if (v <= 0) return 0;
    if (v >= 1000) return 1;
    for (let i = 0; i < GAUGE_MARKS.length - 1; i++) {
      const lo = GAUGE_MARKS[i], hi = GAUGE_MARKS[i + 1];
      if (v <= hi) return (i + (v - lo) / (hi - lo)) / (GAUGE_MARKS.length - 1);
    }
    return 1;
  }
  function gaugeAngle(mbps) {
    return -210 + gaugeFraction(mbps) * 240;
  }
  function fmtSpeed(mbps, unit) {
    if (mbps == null || isNaN(mbps)) return '—';
    const v = unit === 'MB/s' ? mbps / 8 : mbps;
    return v >= 100 ? String(Math.round(v)) : v.toFixed(1);
  }
  function fmtEta(sec) {
    if (sec == null || isNaN(sec) || sec < 0) return '—';
    const m = Math.floor(sec / 60), s = Math.round(sec % 60);
    return String(m).padStart(2, '0') + ':' + String(s).padStart(2, '0');
  }
  function setGauge(mbps) {
    const needle = $('speedNeedle');
    if (needle) needle.style.transform = 'rotate(' + gaugeAngle(mbps) + 'deg)';
    const arc = $('speedArc');
    if (arc) arc.style.strokeDashoffset = String(100 - gaugeFraction(mbps) * 100);
    const val = $('speedValue');
    if (val) val.textContent = fmtSpeed(mbps, speedUnit);
    const unitEl = $('speedUnit');
    if (unitEl) unitEl.textContent = speedUnit;
  }
  function setSpeedUnitUI() {
    document.querySelectorAll('#speedUnitToggle button').forEach(b =>
      b.classList.toggle('selected', b.dataset.unit === speedUnit));
    document.querySelectorAll('.speed-unit-label').forEach(el => { el.textContent = speedUnit; });
    setGauge(speedLastLiveMbps);
    if (speedHasResult) {
      const dl = $('speedDownload'), ul = $('speedUpload');
      if (dl && dl.dataset.mbps) dl.textContent = fmtSpeed(Number(dl.dataset.mbps), speedUnit);
      if (ul && ul.dataset.mbps) ul.textContent = fmtSpeed(Number(ul.dataset.mbps), speedUnit);
    }
  }
  function setSpeedPhase(text) {
    const el = $('speedPhase');
    if (el) el.textContent = text || '';
  }
  function setSpeedProgress(p) {
    const fill = $('speedProgressFill');
    if (fill) fill.style.width = Math.max(0, Math.min(100, p || 0)) * 100 + '%';
  }
  function showSpeedError(msg) {
    const el = $('speedError');
    if (!el) return;
    el.textContent = msg;
    el.classList.remove('hidden');
  }
  function setSpeedButtons(running) {
    const start = $('speedStartBtn'), cancel = $('speedCancelBtn');
    if (start) {
      start.disabled = running;
      start.textContent = running ? t('speedtest_measuring')
        : (speedHasResult ? t('speedtest_again') : t('speedtest_start'));
    }
    if (cancel) cancel.classList.toggle('hidden', !running);
  }
  function resetSpeedResults() {
    speedHasResult = false;
    speedLastLiveMbps = 0;
    ['speedDownload', 'speedUpload', 'speedPing', 'speedJitter'].forEach(id => {
      const el = $(id);
      if (el) { el.textContent = '—'; delete el.dataset.mbps; }
    });
    setGauge(0);
    setSpeedProgress(0);
    setSpeedPhase('');
    $('speedError').classList.add('hidden');
  }
  function fillSpeedResults(res) {
    speedHasResult = true;
    speedLastLiveMbps = res.downloadMbps || 0;
    const dl = $('speedDownload'), ul = $('speedUpload');
    if (dl) { dl.dataset.mbps = String(res.downloadMbps); dl.textContent = fmtSpeed(res.downloadMbps, speedUnit); }
    if (ul) { ul.dataset.mbps = String(res.uploadMbps); ul.textContent = fmtSpeed(res.uploadMbps, speedUnit); }
    if ($('speedPing')) $('speedPing').textContent = res.pingMs != null ? Math.round(res.pingMs) : '—';
    if ($('speedJitter')) $('speedJitter').textContent = res.jitterMs != null ? Math.round(res.jitterMs) : '—';
    setGauge(res.downloadMbps || 0);
    setSpeedProgress(1);
    setSpeedPhase('');
  }
  async function startSpeedTest() {
    if (speedRunning) return;
    if (typeof api.runSpeedTest !== 'function') {
      showSpeedError(t('speedtest_failed'));
      return;
    }
    const runId = ++speedRunId;
    speedRunning = true;
    resetSpeedResults();
    setSpeedButtons(true);
    setSpeedPhase(t('speedtest_measuring'));
    try {
      const res = await api.runSpeedTest();
      if (runId !== speedRunId) return; // cancelled while running
      if (!res || !res.ok) {
        showSpeedError(t('speedtest_failed') + (res && res.error ? ' ' + res.error : ''));
        setSpeedPhase('');
        return;
      }
      fillSpeedResults(res);
    } catch (e) {
      if (runId !== speedRunId) return;
      showSpeedError(t('speedtest_failed') + ' ' + (e && e.message ? e.message : ''));
      setSpeedPhase('');
    } finally {
      if (runId === speedRunId) {
        speedRunning = false;
        setSpeedButtons(false);
      }
    }
  }
  async function cancelSpeedTest() {
    speedRunId++; // invalidate any in-flight run / samples
    speedRunning = false;
    try { if (typeof api.cancelSpeedTest === 'function') await api.cancelSpeedTest(); } catch (_) {}
    setSpeedProgress(0);
    setSpeedPhase('');
    setSpeedButtons(false);
  }
  if (typeof api.onSpeedTestSample === 'function') {
    api.onSpeedTestSample(sample => {
      if (!speedRunning || !sample) return;
      const mbps = sample.currentMbps || 0;
      speedLastLiveMbps = mbps;
      setGauge(mbps);
      setSpeedProgress(sample.progress || 0);
      const phaseKey = { ping: 'speedtest_ping', download: 'speedtest_download', upload: 'speedtest_upload' };
      setSpeedPhase(sample.phase ? (t(phaseKey[sample.phase] || 'speedtest_measuring') + '…') : t('speedtest_measuring'));
    });
  }
  $('speedStartBtn').addEventListener('click', startSpeedTest);
  $('speedCancelBtn').addEventListener('click', cancelSpeedTest);
  document.querySelectorAll('#speedUnitToggle button').forEach(b => b.addEventListener('click', async () => {
    speedUnit = b.dataset.unit;
    settings.speedUnit = speedUnit;
    try { await api.setSetting('speedUnit', speedUnit); } catch (_) {}
    setSpeedUnitUI();
  }));

  // ================= updates =================
  function openUpdateModal(title, body, downloadUrl) {
    $('updateModalTitle').textContent = title;
    $('updateModalBody').innerHTML = body;
    const go = $('updateGoBtn');
    if (downloadUrl) {
      go.classList.remove('hidden');
      go.textContent = t('updateDownload');
      go.onclick = () => api.openExternal(downloadUrl);
    } else go.classList.add('hidden');
    $('updateCloseBtn').textContent = t('close');
    $('updateModal').classList.remove('hidden');
  }
  $('updateCloseBtn').addEventListener('click', () => $('updateModal').classList.add('hidden'));
  $('updateModal').addEventListener('click', e => { if (e.target === $('updateModal')) $('updateModal').classList.add('hidden'); });
  // Returns the check result (or null on failure). When an update is
  // available it is rendered into the Apple-style card in #sub-updates and
  // that sub-screen is opened (unless the check was silent). The modal is
  // kept ONLY for the checking / up-to-date / error states.
  async function checkUpdates(silent) {
    if (!silent) openUpdateModal(t('updateChecking'), t('updateWait'), null);
    try {
      const res = await api.checkUpdates();
      if (!res.ok) {
        if (!silent) openUpdateModal(t('updateFail'), esc(res.error || 'Unknown error.'), null);
        return null;
      }
      if (res.update) {
        latestUpdate = res;
        renderUpdateCard(res);
        if (!silent) {
          $('updateModal').classList.add('hidden');
          openSubScreen('updates');
        }
        return res;
      }
      if (!silent) {
        openUpdateModal(t('updateLatest'), t('updateLatestBody', { version: res.version }), null);
      }
      return res;
    } catch (e) {
      if (!silent) openUpdateModal(t('updateFail'), esc(e.message), null);
      return null;
    }
  }
  $('updateBtn').addEventListener('click', () => checkUpdates(false));
  $('aboutUpdateBtn').addEventListener('click', () => checkUpdates(false));

  // ================= about =================
  $('portfolioBtn').addEventListener('click', () => {
    if (appInfo && appInfo.portfolioUrl) api.openExternal(appInfo.portfolioUrl);
  });

  // ================= YouTube tab =================
  const ytView = $('ytView');
  const isWebview = ytView && typeof ytView.getURL === 'function';
  // Tell the in-app webview overlay which language the UI is in.
  function syncYtLang() {
    if (!isWebview) return;
    try { const p = ytView.executeJavaScript(`window.__snapdlLang='${lang}';`); if (p && p.catch) p.catch(() => {}); } catch (_) {}
  }
  function ytSetUrl(url) {
    if (!url) return;
    $('ytUrl').textContent = url.replace(/^https?:\/\//, '').split('/')[0] + (url.includes('/watch') ? ' / watch' : '');
  }
  if (isWebview) {
    ytView.addEventListener('did-navigate', e => ytSetUrl(e.url));
    ytView.addEventListener('did-navigate-in-page', e => ytSetUrl(e.url));
    ytView.addEventListener('did-finish-load', () => { ytSetUrl(ytView.getURL()); syncYtLang(); console.log('[yt] loaded: ' + ytView.getURL()); });
    ytView.addEventListener('did-fail-load', e => console.log('[yt] failed: ' + e.errorCode + ' ' + e.errorDescription + ' ' + (e.validatedURL || '')));
    ytView.addEventListener('new-window', e => { e.preventDefault(); api.openExternal(e.url); });
    $('ytBack').addEventListener('click', () => { try { ytView.goBack(); } catch (_) {} });
    $('ytForward').addEventListener('click', () => { try { ytView.goForward(); } catch (_) {} });
    $('ytReload').addEventListener('click', () => { try { ytView.reload(); } catch (_) {} });
    $('ytHome').addEventListener('click', () => { try { ytView.loadURL('https://www.youtube.com/'); } catch (_) {} });
    $('ytDownloadBtn').addEventListener('click', async () => {
      let url = '';
      try { url = ytView.getURL(); } catch (_) {}
      if (!url || !/youtube\.com\/watch/i.test(url)) { toast(t('toastNoVideo')); return; }
      const res = await api.startDownload({ url, quality: settings.defaultQuality || 'highest' });
      if (!res.ok) toast(res.error || t('toastStartFail'));
      else if (res.queued) toast(t('toastQueued'));
      else showView('download');
    });
  } else {
    // No webview (plain browser render): disable the toolbar gracefully.
    ['ytBack', 'ytForward', 'ytReload', 'ytHome', 'ytDownloadBtn'].forEach(id => { const b = $(id); if (b) b.disabled = true; });
  }

  // ================= preview mode (screenshots) =================
  let previewApplied = false;
  api.onPreviewState(state => {
    previewApplied = true;
    if (state.info) {
      $('urlInput').value = state.job ? state.job.url : '';
      $('previewCard').classList.remove('hidden');
      $('previewLoading').classList.add('hidden');
      $('previewBody').classList.remove('hidden');
      fillPreview(state.info, state.job ? state.job.url : '');
      if (state.info.maxHeight) applyMaxHeight(state.info.maxHeight);
    }
    if (state.job) {
      markQuality('qualityGrid', state.job.quality);
      selectedQuality = state.job.quality;
      renderJobs([state.job]);
    }
    if (state.history) { history = state.history; renderHistory(); }
    if (state.logs) { logs = state.logs; renderLogs(); }
  });
  api.onPreviewShowView(view => showView(view));
  api.onPreviewShowSub(sub => openSubScreen(sub));

  // ================= init =================
  (async () => {
    try {
      settings = Object.assign(settings, await api.getSettings());
    } catch (_) {}
    lang = settings.language || 'ar';
    applyI18n();
    applyTheme();
    selectedQuality = settings.defaultQuality || 'highest';
    markQuality('qualityGrid', selectedQuality);
    speedUnit = settings.speedUnit === 'MB/s' ? 'MB/s' : 'Mbps';
    setSpeedUnitUI();
    markOptions();
    applyAllStagger(document);
    try {
      appInfo = await api.appInfo();
      $('versionLabel').textContent = `SnapDL v${appInfo.version}`;
      $('aboutVersion').textContent = t('aboutVersion', { v: appInfo.version });
    } catch (_) {}
    try { await refreshFolder(); } catch (_) {}
    try { const h = await api.getHistory(); if (!previewApplied) { history = h; renderHistory(); } } catch (_) {}
    try { const l = await api.getLogs(); if (!previewApplied) { logs = l; renderLogs(); } } catch (_) {}
    if (IS_MOCK) {
      // Standalone browser render: show sample data so the design is visible.
      history = [
        { id: 1, title: 'Big Buck Bunny — 4K 60fps Official Trailer', platform: 'YouTube', quality: '1080p', url: '', path: '', size: 191526400, date: new Date().toISOString(), status: 'done' },
        { id: 2, title: 'TikTok — funny cat compilation (no watermark)', platform: 'TikTok', quality: 'highest', url: '', path: '', size: 12450000, date: new Date().toISOString(), status: 'done' }
      ];
      renderHistory();
      logs = [
        { time: new Date().toISOString(), category: 'DOWNLOAD', level: 'info', message: 'Finished: Big Buck Bunny — 4K 60fps Official Trailer (182.6 MB)' },
        { time: new Date().toISOString(), category: 'UPDATE', level: 'info', message: 'You are on the latest version (1.0.0).' },
        { time: new Date().toISOString(), category: 'SYSTEM', level: 'info', message: 'SnapDL started.' }
      ];
      renderLogs();
      renderJobs([{
        id: 1, url: 'https://www.youtube.com/watch?v=aqz-KE-bpKQ', quality: '1080p',
        status: 'downloading', progress: 47.3, speed: '8.4 MiB/s', eta: '00:41',
        sizeTotal: '182.6 MiB', phase: 'downloading',
        title: 'Big Buck Bunny — 4K 60fps Official Trailer (Sample)', platform: 'YouTube'
      }]);
    }
    // Automatic update check (only when enabled in Settings → Updates).
    if (settings.autoCheck && !IS_MOCK) setTimeout(() => checkUpdates(true), 3000);
  })();
})();

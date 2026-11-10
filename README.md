# SnapDL

**SnapDL** — برنامج تحميل فيديوهات من يوتيوب وتيك توك وإنستجرام وفيسبوك وإكس.
الصق رابطًا، اختر الجودة، وحمّل. بدون إعلانات، بدون حسابات.

**SnapDL** — download videos from YouTube, TikTok, Instagram, Facebook and X.
Paste a link, pick a quality, download. No ads, no accounts.

## التنزيل / Download

من صفحة الإصدارات: [Releases](https://github.com/mohamed5946/video-downloader/releases/latest)

- **Windows:** `SnapDL-win32-x64.zip` — فك الضغط وشغّل `SnapDL.exe`
- **Android:** `SnapDL-v1.0.0.apk` — ثبّت الملف على موبايلك

## المصدر / Source

- `windows/` — نسخة الكمبيوتر (Electron). طريقة البناء في `windows/BUILD.md`
- `android/` — نسخة الموبايل (Flutter). تُبنى تلقائيًا عبر GitHub Actions عند كل تحديث

## التحديثات / Updates

البرنامج يفحص التحديثات من داخل التطبيق (الإعدادات ← التحديثات) عبر ملف
`update.json` المرفق مع كل إصدار.

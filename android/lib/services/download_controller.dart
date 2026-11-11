import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models.dart';
import 'engine_service.dart';
import 'history_service.dart';
import 'log_service.dart';
import 'settings_service.dart';

/// Owns the download state for the Home screen: URL, formats, picker,
/// active downloads (progress/speed/ETA/pause/resume), and history actions.
class DownloadController extends ChangeNotifier {
  DownloadController() {
    _progressSub = EngineService.instance.progressStream.listen(_onProgress);
  }

  final _log = LogService.instance;
  final _engine = EngineService.instance;
  final _history = HistoryService.instance;

  StreamSubscription? _progressSub;

  String url = '';
  PlatformKind platform = PlatformKind.unknown;
  String videoTitle = '';
  int videoDurationSeconds = 0;
  String thumbnailUrl = '';
  String streamUrl = '';
  bool fetchingFormats = false;
  String? fetchError;
  List<FormatOption> formats = [];
  FormatOption? selectedFormat;

  final List<ActiveDownload> active = [];
  List<HistoryEntry> get history => _history.items;
  Listenable get historyListenable => _history;

  String downloadDirPath = '';
  bool _dirResolved = false;

  void setUrl(String value) {
    url = value.trim();
    platform = PlatformKindX.detect(url);
    if (formats.isNotEmpty) {
      formats = [];
      selectedFormat = null;
      videoTitle = '';
      videoDurationSeconds = 0;
      thumbnailUrl = '';
      streamUrl = '';
    }
    fetchError = null;
    notifyListeners();
  }

  void selectFormat(FormatOption format) {
    selectedFormat = format;
    notifyListeners();
  }

  Future<String> resolveDownloadDir() async {
    if (_dirResolved && downloadDirPath.isNotEmpty) return downloadDirPath;
    // 'App folder' setting: skip the public folder entirely.
    if (SettingsService.instance.downloadLocation == 'app') {
      final ext = await getExternalStorageDirectory();
      final dir = Directory('${ext?.path ?? ''}/SnapDL');
      await dir.create(recursive: true);
      downloadDirPath = dir.path;
      _dirResolved = true;
      _log.add(LogCategory.storage, 'Download folder: $downloadDirPath');
      return downloadDirPath;
    }
    try {
      // Public Downloads/SnapDL when all-files access is granted.
      if (await Permission.manageExternalStorage.isGranted) {
        final dir = Directory('/storage/emulated/0/Download/SnapDL');
        await dir.create(recursive: true);
        downloadDirPath = dir.path;
        _dirResolved = true;
        _log.add(LogCategory.storage,
            'Download folder: $downloadDirPath');
        return downloadDirPath;
      }
      final status = await Permission.manageExternalStorage.request();
      if (status.isGranted) {
        final dir = Directory('/storage/emulated/0/Download/SnapDL');
        await dir.create(recursive: true);
        downloadDirPath = dir.path;
        _dirResolved = true;
        _log.add(LogCategory.storage,
            'Download folder: $downloadDirPath');
        return downloadDirPath;
      }
      _log.add(LogCategory.storage,
          'All-files access not granted — using app folder');
    } catch (e) {
      _log.error(LogCategory.storage, 'Public folder failed', e.toString());
    }
    // Fallback: app-specific external storage (always writable).
    final ext = await getExternalStorageDirectory();
    final dir = Directory('${ext?.path ?? ''}/SnapDL');
    await dir.create(recursive: true);
    downloadDirPath = dir.path;
    _dirResolved = true;
    _log.add(LogCategory.storage, 'Download folder: $downloadDirPath');
    return downloadDirPath;
  }

  Future<void> fetchFormats() async {
    if (url.isEmpty) return;
    fetchingFormats = true;
    fetchError = null;
    notifyListeners();
    try {
      await resolveDownloadDir();
      final info = await _engine.fetchInfo(url);
      formats = info.formats;
      // Default quality from Settings (label match, else first option).
      final want = SettingsService.instance.defaultQuality;
      selectedFormat = info.formats.isNotEmpty
          ? info.formats.firstWhere((f) => f.label == want,
              orElse: () => info.formats.first)
          : null;
      // The video's ORIGINAL title from its site — this is also the
      // filename yt-dlp saves (output template %(title)s.%(ext)s).
      videoTitle =
          info.title.isEmpty ? _titleFromUrl(url) : info.title;
      videoDurationSeconds = info.durationSeconds;
      thumbnailUrl = info.thumbnailUrl;
      streamUrl = info.streamUrl;
    } catch (e) {
      fetchError = e.toString().replaceFirst('Exception: ', '');
      _log.error(LogCategory.download, 'Could not read link', fetchError!);
    } finally {
      fetchingFormats = false;
      notifyListeners();
    }
  }

  String _titleFromUrl(String u) {
    final host = Uri.tryParse(u)?.host ?? '';
    if (host.isEmpty) {
      return SettingsService.instance.tr('video_fallback');
    }
    return SettingsService.instance.trf('video_from_host', {'host': host});
  }

  Future<void> startDownload() async {
    final format = selectedFormat;
    if (url.isEmpty || format == null) return;
    // Wi-Fi-only setting: refuse on mobile data.
    if (SettingsService.instance.wifiOnly) {
      final results = await Connectivity().checkConnectivity();
      if (!results.contains(ConnectivityResult.wifi)) {
        fetchError = SettingsService.instance.tr('err_wifi_only');
        _log.add(LogCategory.download,
            'Download blocked: Wi-Fi only is on, not on Wi-Fi');
        notifyListeners();
        return;
      }
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final item = ActiveDownload(
      id: id,
      url: url,
      title: videoTitle.isEmpty ? _titleFromUrl(url) : videoTitle,
      platform: platform,
      qualityLabel: format.label,
      isAudioOnly: format.isAudioOnly,
      status: DownloadStatus.downloading,
    );
    active.insert(0, item);
    _log.add(LogCategory.download,
        'Download started: ${item.title} (${format.label})');
    notifyListeners();
    // Max simultaneous downloads: queue when all slots are busy.
    final running =
        active.where((a) => a.status == DownloadStatus.downloading).length;
    if (running > SettingsService.instance.maxSimultaneous) {
      item.status = DownloadStatus.queued;
      _log.add(LogCategory.download,
          'Queued: ${item.title} (max ${SettingsService.instance.maxSimultaneous} at a time)');
      notifyListeners();
      return;
    }
    await _runEngine(item, format.id, format.isAudioOnly,
        expectedTotalBytes: format.sizeBytes, title: item.title);
  }

  /// Start queued downloads while a slot is free.
  Future<void> _pumpQueue() async {
    final max = SettingsService.instance.maxSimultaneous;
    while (active.where((a) => a.status == DownloadStatus.downloading).length <
        max) {
      ActiveDownload? next;
      for (final a in active) {
        if (a.status == DownloadStatus.queued) {
          next = a;
          break;
        }
      }
      if (next == null) return;
      final format = formats.firstWhere(
        (f) => f.label == next!.qualityLabel,
        orElse: () => FormatOption(
          id: 'bestvideo+bestaudio/best',
          label: 'Highest',
          detail: '',
          isAudioOnly: next!.isAudioOnly,
          height: 0,
          sizeText: '',
        ),
      );
      next.status = DownloadStatus.downloading;
      notifyListeners();
      await _runEngine(next, format.id, format.isAudioOnly,
          expectedTotalBytes: format.sizeBytes, title: next.title);
    }
  }

  Future<void> _runEngine(
      ActiveDownload item, String formatId, bool audioOnly,
      {int expectedTotalBytes = 0, String title = '', bool resume = false}) async {
    _ensureWatchdog();
    try {
      // v1.0.6: the native call returns true when the download
      // reported finished. The 'done' event normally arrives first,
      // but the v1.0.5 field bug was exactly a finished download whose
      // event never arrived — so a true result also completes the item
      // (after a short grace for the event), via the folder check.
      final ok = resume
          ? await _engine.resumeDownload(
              id: item.id,
              url: item.url,
              formatId: formatId,
              audioOnly: audioOnly,
              expectedTotalBytes: expectedTotalBytes,
              title: title,
            )
          : await _engine.startDownload(
              id: item.id,
              url: item.url,
              formatId: formatId,
              audioOnly: audioOnly,
              expectedTotalBytes: expectedTotalBytes,
              title: title,
            );
      if (ok && item.status == DownloadStatus.downloading) {
        await Future.delayed(const Duration(seconds: 3));
        if (item.status == DownloadStatus.downloading) {
          await _resolveStalled(item);
        }
      }
    } catch (e) {
      item.status = DownloadStatus.error;
      // v1.0.5: the UI shows a generic message; the log gets the
      // sanitized text (never raw native wording).
      item.error = SettingsService.instance.tr('download_failed');
      _log.error(LogCategory.download,
          resume ? 'Resume failed' : 'Download failed to start',
          EngineService.sanitizeEngineText(e.toString()));
      notifyListeners();
      await _pumpQueue();
    }
  }

  // ------------------------------------------------------- watchdog (v1.0.6)

  Timer? _watchdog;

  /// The 100% hang (2026-11-11 field report): the file was complete
  /// but the native 'done' event never arrived, so the card stayed
  /// stuck at 100% forever. A periodic check resolves any download
  /// that goes quiet: at 100% with no event for 15s it looks for the
  /// finished file in the download folder; silent for 5 minutes at
  /// any progress it is a stall and fails with a clear message.
  void _ensureWatchdog() {
    _watchdog ??= Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateTime.now();
      var anyDownloading = false;
      for (final item in List.of(active)) {
        if (item.status != DownloadStatus.downloading) continue;
        anyDownloading = true;
        final silent = now.difference(item.lastEventAt);
        if (item.progress >= 1.0 && silent > const Duration(seconds: 15)) {
          unawaited(_resolveStalled(item));
        } else if (silent > const Duration(minutes: 5)) {
          item.status = DownloadStatus.error;
          item.error = SettingsService.instance.tr('download_failed');
          _log.error(LogCategory.download,
              'Download stalled with no progress for 5 minutes',
              item.title);
          notifyListeners();
          unawaited(_pumpQueue());
        }
      }
      if (!anyDownloading) {
        _watchdog?.cancel();
        _watchdog = null;
      }
    });
  }

  /// A download went quiet at (or after) 100% with no done/error
  /// event. If the finished file is in the download folder, the
  /// download is done — the event was lost, the file was not.
  /// Otherwise it really failed.
  Future<void> _resolveStalled(ActiveDownload item) async {
    if (item.status != DownloadStatus.downloading) return;
    String? foundPath;
    var foundSize = 0;
    try {
      final dir = await _engine.downloadDir();
      if (dir.isNotEmpty) {
        final d = Directory(dir);
        if (await d.exists()) {
          final files = await d
              .list()
              .where((e) => e is File)
              .cast<File>()
              .toList();
          final picked =
              pickFinishedFile(files, item.title, item.startedAt);
          if (picked != null) {
            foundPath = picked.path;
            foundSize = await picked.length();
          }
        }
      }
    } catch (_) {
      // Folder unreadable — treat as not found below.
    }
    if (foundPath != null) {
      _log.add(LogCategory.download,
          'Finished (recovered without done event): ${item.title} → $foundPath');
      _finishItem(item, foundPath, foundSize);
      return;
    }
    item.status = DownloadStatus.error;
    item.error = SettingsService.instance.tr('download_failed');
    _log.error(LogCategory.download,
        'Download finished signalling but no file found', item.title);
    notifyListeners();
    await _pumpQueue();
  }

  /// Pick the finished file for [title] out of [files]: a real file
  /// (never a .part), non-empty, written after the download started,
  /// preferring a name that contains the title. Falls back to the
  /// newest such file. Pure enough to unit-test.
  static File? pickFinishedFile(
      List<File> files, String title, DateTime since) {
    final key = _titleKey(title);
    File? newest;
    DateTime? newestTime;
    File? titled;
    DateTime? titledTime;
    for (final f in files) {
      if (f.path.endsWith('.part')) continue;
      FileStat stat;
      try {
        stat = f.statSync();
      } catch (_) {
        continue; // Vanished between listing and stat.
      }
      if (stat.size <= 0) continue;
      if (stat.modified
          .isBefore(since.subtract(const Duration(minutes: 2)))) {
        continue;
      }
      if (newestTime == null || stat.modified.isAfter(newestTime)) {
        newest = f;
        newestTime = stat.modified;
      }
      if (key.length >= 6 &&
          f.uri.pathSegments.last.contains(key) &&
          (titledTime == null || stat.modified.isAfter(titledTime))) {
        titled = f;
        titledTime = stat.modified;
      }
    }
    return titled ?? newest;
  }

  /// First characters of the title, as they appear in the saved
  /// filename (the download tool keeps the title text — spaces
  /// included — only stripping characters illegal in filenames).
  /// v1.0.6: spaces MUST be kept — dropping them made the key
  /// ("عمركسألتنفسك") never match the filename ("عمرك سألت…").
  static String _titleKey(String title) {
    final kept = title.replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f]'), '');
    return kept.length > 12 ? kept.substring(0, 12) : kept;
  }

  /// Shared by the 'done' event and the watchdog: mark finished,
  /// move to history, clear the input for the next link.
  void _finishItem(ActiveDownload item, String? filePath, int fileSize) {
    item.status = DownloadStatus.done;
    item.progress = 1;
    item.filePath = filePath;
    if (fileSize > 0) item.fileSizeBytes = fileSize;
    active.remove(item);
    _history.add(HistoryEntry(
      id: item.id,
      url: item.url,
      title: item.title,
      platform: item.platform,
      qualityLabel: item.qualityLabel,
      isAudioOnly: item.isAudioOnly,
      date: DateTime.now(),
      filePath: item.filePath ?? '',
      fileSizeBytes: item.fileSizeBytes,
    ));
    _log.add(LogCategory.download,
        'Finished: ${item.title} → ${item.filePath ?? ''}');
    // Clear the input for the next link.
    url = '';
    formats = [];
    selectedFormat = null;
    videoTitle = '';
    videoDurationSeconds = 0;
    thumbnailUrl = '';
    streamUrl = '';
    notifyListeners();
    unawaited(_pumpQueue());
  }

  Future<void> pause(String id) async {
    final item = _find(id);
    if (item == null || item.status != DownloadStatus.downloading) return;
    try {
      await _engine.pauseDownload(id);
      item.status = DownloadStatus.paused;
      _log.add(LogCategory.download, 'Paused: ${item.title}');
    } catch (e) {
      _log.error(LogCategory.download, 'Pause failed',
          EngineService.sanitizeEngineText(e.toString()));
    }
    notifyListeners();
  }

  Future<void> resume(String id) async {
    final item = _find(id);
    if (item == null || item.status != DownloadStatus.paused) return;
    // Respect the max-simultaneous limit on resume too.
    final running =
        active.where((a) => a.status == DownloadStatus.downloading).length;
    if (running >= SettingsService.instance.maxSimultaneous) {
      _log.add(LogCategory.download,
          'Resume waiting: all ${SettingsService.instance.maxSimultaneous} slot(s) busy');
      return;
    }
    final format = formats.firstWhere(
      (f) => f.label == item.qualityLabel,
      orElse: () => FormatOption(
        id: 'bestvideo+bestaudio/best',
        label: 'Highest',
        detail: '',
        isAudioOnly: item.isAudioOnly,
        height: 0,
        sizeText: '',
      ),
    );
    item.status = DownloadStatus.downloading;
    // v1.0.6: resume continues from the .part — the native side seeds
    // the bar from the bytes already on disk, so it never drops back
    // to 0%. The item's progress is kept as-is until the first new
    // progress event arrives.
    item.resumeCount++;
    _log.add(LogCategory.download,
        'Resuming (continues from the same point): ${item.title}');
    notifyListeners();
    await _runEngine(item, format.id, format.isAudioOnly,
        expectedTotalBytes: format.sizeBytes,
        title: item.title,
        resume: true);
  }

  Future<void> cancel(String id) async {
    final item = _find(id);
    if (item == null) return;
    try {
      await _engine.cancelDownload(id);
    } catch (_) {}
    item.status = DownloadStatus.cancelled;
    active.remove(item);
    _log.add(LogCategory.download, 'Cancelled: ${item.title}');
    notifyListeners();
  }

  void _onProgress(Map<String, dynamic> event) {
    final id = event['id'] as String?;
    final item = id == null ? null : _find(id);
    if (item == null) return;
    // v1.0.6: every event refreshes the watchdog clock.
    item.lastEventAt = DateTime.now();
    final status = event['status'] as String?;
    if (status == 'done') {
      _finishItem(
        item,
        event['filePath'] as String?,
        (event['fileSizeBytes'] as num?)?.toInt() ?? 0,
      );
      return;
    }
    if (status == 'error') {
      item.status = DownloadStatus.error;
      // v1.0.5: the native error text is already sanitized, but the UI
      // still shows only the generic message — the detail belongs in
      // the log, not on screen.
      final raw = event['error'] as String?;
      item.error = SettingsService.instance.tr('download_failed');
      _log.error(LogCategory.download, 'Download error: ${item.title}',
          raw == null ? null : EngineService.sanitizeEngineText(raw));
      notifyListeners();
      _pumpQueue();
      return;
    }
    final p = (event['progress'] as num?)?.toDouble() ?? 0;
    item.progress = (p / 100).clamp(0, 1);
    item.speed = (event['speed'] as String?) ?? '';
    item.etaSeconds = (event['etaSeconds'] as num?)?.toInt() ?? 0;
    notifyListeners();
  }

  ActiveDownload? _find(String id) {
    for (final a in active) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// v1.0.6: returns false when the file is gone or no app could
  /// open it — the caller shows a clear message instead of silently
  /// doing nothing (the 2026-11-11 field report: "open" did nothing).
  Future<bool> openFile(String path) async {
    if (path.isEmpty) return false;
    final file = File(path);
    if (!await file.exists()) {
      _log.error(LogCategory.storage, 'File not found', path);
      return false;
    }
    final ok = await _engine.openFile(path);
    _log.add(LogCategory.storage,
        ok ? 'Opened file: $path' : 'No app could open: $path');
    return ok;
  }

  Future<void> redownload(HistoryEntry entry) async {
    setUrl(entry.url);
    await fetchFormats();
    final match = formats.where((f) => f.label == entry.qualityLabel);
    if (match.isNotEmpty) selectedFormat = match.first;
    notifyListeners();
    await startDownload();
  }

  Future<void> deleteHistory(String id) async {
    await _history.remove(id);
    _log.add(LogCategory.storage, 'History entry deleted');
    notifyListeners();
  }

  /// Seeds realistic demo state for UI previews (web screenshots).
  /// Never used on a real device — only when the web build is opened
  /// with ?preview=home|history|about.
  Future<void> seedDemo(String which) async {
    if (which == 'home') {
      url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      platform = PlatformKind.youtube;
      videoTitle = 'How AI Actually Works — Explained Simply';
      videoDurationSeconds = 12 * 60 + 34;
      thumbnailUrl = 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg';
      // Sample stream so the card's play button renders in the preview.
      streamUrl =
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
      formats = [
        FormatOption(
          id: 'bestvideo+bestaudio/best',
          label: 'Highest',
          detail: 'Best video + best audio, merged to MP4',
          isAudioOnly: false,
          height: 4320,
          sizeText: '—',
        ),
        FormatOption(
          id: 'bestvideo[height<=2160]+bestaudio/best[height<=2160]',
          label: '4K',
          detail: 'mp4 · 3840×2160 · 84.2 MB',
          isAudioOnly: false,
          height: 2160,
          sizeText: '84.2 MB',
        ),
        FormatOption(
          id: 'bestvideo[height<=1080]+bestaudio/best[height<=1080]',
          label: '1080p',
          detail: 'mp4 · 1920×1080 · 42.6 MB',
          isAudioOnly: false,
          height: 1080,
          sizeText: '42.6 MB',
        ),
        FormatOption(
          id: 'bestvideo[height<=720]+bestaudio/best[height<=720]',
          label: '720p',
          detail: 'mp4 · 1280×720 · 21.3 MB',
          isAudioOnly: false,
          height: 720,
          sizeText: '21.3 MB',
        ),
        FormatOption(
          id: 'worstvideo+worstaudio/worst',
          label: 'Lowest',
          detail: 'Smallest file, fastest download',
          isAudioOnly: false,
          height: 144,
          sizeText: '—',
        ),
        FormatOption(
          id: '__audio_mp3__',
          label: 'Audio MP3',
          detail: 'Sound only, converted to MP3',
          isAudioOnly: true,
          height: 0,
          sizeText: '—',
        ),
      ];
      selectedFormat = formats[2];
      active.add(ActiveDownload(
        id: 'demo-1',
        url: url,
        title: 'How AI Actually Works — Explained Simply',
        platform: PlatformKind.youtube,
        qualityLabel: '1080p',
        isAudioOnly: false,
        progress: 0.62,
        speed: '4.2 MB/s',
        etaSeconds: 18,
        status: DownloadStatus.downloading,
      ));
      notifyListeners();
    } else if (which == 'history') {
      // FIXED dates (not DateTime.now()): the history golden test renders
      // these times, so relative dates made it drift on every run.
      await _history.add(HistoryEntry(
        id: 'demo-h3',
        url: 'https://www.instagram.com/reel/xyz789/',
        title: 'Sunset timelapse — Santorini',
        platform: PlatformKind.instagram,
        qualityLabel: 'Audio MP3',
        isAudioOnly: true,
        date: DateTime(2026, 11, 8, 20, 39),
        filePath: '/storage/emulated/0/Download/SnapDL/sunset.mp3',
        fileSizeBytes: 6 * 1024 * 1024,
      ));
      await _history.add(HistoryEntry(
        id: 'demo-h2',
        url: 'https://www.tiktok.com/@creator/video/7391829471920',
        title: 'The beat drop that broke the internet',
        platform: PlatformKind.tiktok,
        qualityLabel: '720p',
        isAudioOnly: false,
        date: DateTime(2026, 11, 9, 15, 39),
        filePath: '/storage/emulated/0/Download/SnapDL/beat-drop.mp4',
        fileSizeBytes: 12 * 1024 * 1024,
      ));
      await _history.add(HistoryEntry(
        id: 'demo-h1',
        url: 'https://www.youtube.com/watch?v=abc123',
        title: 'Flutter in 10 Minutes — Full Crash Course',
        platform: PlatformKind.youtube,
        qualityLabel: '1080p',
        isAudioOnly: false,
        date: DateTime(2026, 11, 10, 18, 39),
        filePath: '/storage/emulated/0/Download/SnapDL/Flutter in 10 Minutes.mp4',
        fileSizeBytes: 186 * 1024 * 1024,
      ));
      notifyListeners();
    }
  }

  Future<void> pasteFromClipboard() async {    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isNotEmpty) setUrl(text);
    } catch (e) {
      _log.error(LogCategory.ui, 'Paste failed', e.toString());
    }
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _watchdog = null;
    _progressSub?.cancel();
    super.dispose();
  }
}

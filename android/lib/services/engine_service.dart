import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models.dart';
import 'log_service.dart';
import 'settings_service.dart';

/// Result of a download-tool update attempt.
enum ToolUpdateResult {
  /// A newer tool version was installed.
  done,

  /// The tool is already on the latest release.
  upToDate,

  /// The update did not complete (offline, timeout, server error).
  /// The bundled version keeps working.
  failed,
}

/// Bridge to the native yt-dlp engine (youtubedl-android, Maven Central
/// io.github.junkfood02.youtubedl-android 0.18.1 — CPython 3.11 + yt-dlp
/// bundled as native .so per ABI, same engine Seal / YTDLnis use).
///
/// The official yt-dlp Linux aarch64 binary is dynamically linked against
/// glibc and CANNOT run on Android — that is why the app uses the
/// youtubedl-android library instead of a raw binary.
///
/// v1.0.5: the bundled extractor goes stale when sites change their
/// pages (TikTok, 2026-11-11 field report) — the library's own updater
/// (updateYoutubeDL, STABLE channel) fetches the latest release and the
/// app uses it for all later extractions. The update runs in the
/// background: once on first init, then at most once a week, plus
/// on-demand from Settings → Updates, plus one automatic retry when a
/// fetch fails with FORMATS. A failed update never breaks downloads —
/// the bundled version keeps working.
class EngineService {
  EngineService._();

  static final EngineService instance = EngineService._();

  static const _method = MethodChannel('com.valor.snapdl/engine');
  static const _events = EventChannel('com.valor.snapdl/engine_events');

  bool _initialized = false;
  String _engineVersion = '';
  StreamSubscription? _sub;

  // v1.0.5: guard concurrent tool updates, and remember whether the
  // updater already reached its server this session (a second attempt
  // after an up-to-date answer would fail the same way again).
  Future<ToolUpdateResult>? _toolUpdateRunning;
  bool _toolUpdateAttempted = false;

  bool get initialized => _initialized;
  String get engineVersion => _engineVersion;

  /// Dart mirror of the native sanitizeText: strip URLs and any
  /// download-tool naming from a message before it reaches the
  /// diagnostics log or the UI.
  static String sanitizeEngineText(String text) {
    var out = text.replaceAll('\n', ' ').replaceAll('\r', ' ');
    out = out.replaceAll(RegExp(r'https?://\S+'), '');
    for (final word in [
      'yt-dlp',
      'ytdlp',
      'youtube-dl',
      'youtubedl',
      'libffmpeg',
      'ffmpeg',
      'engine',
    ]) {
      out = out.replaceAll(RegExp(word, caseSensitive: false), 'service');
    }
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    return out.length > 300 ? out.substring(0, 300) : out;
  }

  /// v1.0.5: is a background tool update due? First run ever, or the
  /// last successful update is over a week old.
  static bool isUpdateDue(int lastCheckMs, int nowMs) {
    if (lastCheckMs <= 0) return true;
    return nowMs - lastCheckMs > const Duration(days: 7).inMilliseconds;
  }

  final _progressController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// {id, progress 0-1, speed, etaSeconds, status: progress|done|error, error?}
  Stream<Map<String, dynamic>> get progressStream =>
      _progressController.stream;

  Future<bool> init() async {
    if (_initialized) return true;
    _sub ??= _events.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        _progressController.add(Map<String, dynamic>.from(event));
      }
    }, onError: (Object e) {
      LogService.instance.error(
          LogCategory.engine, 'Download event stream error', e.toString());
    });
    // v1.0.3: log free internal storage at setup time (helps rule
    // storage in or out of a startup failure).
    await _logFreeSpace();
    // v1.0.3: one automatic retry — the first setup can fail
    // transiently. The native side queues a second call while one is
    // in progress, so the retry never starts a second extraction.
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        // v1.0.3: 120s — the first setup can be slow.
        final res = await _method
            .invokeMethod<String>('init')
            .timeout(const Duration(seconds: 120));
        _engineVersion = res ?? '';
        _initialized = true;
        LogService.instance.add(
            LogCategory.engine, 'Download service ready');
        // v1.0.5: background tool update — first run ever, then weekly.
        // Fire-and-forget: never blocks startup or the first download.
        unawaited(maybeAutoUpdateTool());
        return true;
      } on MissingPluginException {
        LogService.instance.error(LogCategory.engine, 'Download service unavailable',
            'Download service is not present in this build');
        return false;
      } on TimeoutException {
        LogService.instance.error(LogCategory.engine,
            'Download service failed to start',
            'Timed out while starting (attempt $attempt of 2)');
      } on PlatformException catch (e) {
        // v1.0.3: log the full failure including the native diagnostics
        // string (type, message, frames, free space) — the message
        // alone was null on the field device.
        // v1.0.5: the native message is sanitized, but the code and the
        // details are logged — never the raw message itself.
        LogService.instance.error(LogCategory.engine,
            'Download service failed to start',
            sanitizeEngineText(e.details?.toString() ?? ''));
      } catch (e) {
        LogService.instance.error(LogCategory.engine,
            'Download service failed to start', sanitizeEngineText(e.toString()));
      }
      if (attempt == 1) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return false;
  }

  Future<void> _logFreeSpace() async {
    try {
      final mb = await _method.invokeMethod<int>('freeSpaceMb');
      if (mb != null) {
        LogService.instance.add(LogCategory.storage, 'Free space: $mb MB');
      }
    } catch (_) {
      // Non-fatal: setup proceeds without the number.
    }
  }

  Future<String> version() async {
    if (!_initialized) {
      final ok = await init();
      if (!ok) return '';
    }
    return _engineVersion;
  }

  /// Fetch metadata + available formats via `yt-dlp -J` and build the
  /// preview card data (original title, duration, thumbnail, stream URL).
  ///
  /// v1.0.5: a fetch failure NEVER lets a raw native message escape —
  /// the UI and the log only ever see generic localized text (the field
  /// screenshot showed the raw extractor error, github link included).
  /// A FORMATS failure updates the download tool once and retries the
  /// fetch, because a stale bundled extractor is the usual cause when
  /// a site changed its pages.
  Future<VideoInfo> fetchInfo(String url) async {
    final log = LogService.instance;
    if (!await init()) {
      throw Exception(SettingsService.instance.tr('engine_unavailable'));
    }
    log.add(LogCategory.engine, 'Getting video info', url);
    try {
      final info = await _fetchInfoOnce(url);
      if (info != null) return info;
      throw Exception(SettingsService.instance.tr('engine_no_formats'));
    } on PlatformException catch (e) {
      if (e.code == 'FORMATS') {
        // The log records the code only; the raw message never reaches
        // the log or the UI.
        log.error(LogCategory.engine, 'Could not get video info', 'FORMATS');
        if (await _updateToolOnce()) {
          try {
            final retried = await _fetchInfoOnce(url);
            if (retried != null) return retried;
          } on PlatformException catch (e2) {
            log.error(
                LogCategory.engine, 'Could not get video info', e2.code);
          } catch (_) {}
        }
        throw Exception(SettingsService.instance.tr('formats_unreadable'));
      }
      log.error(LogCategory.engine, 'Could not get video info', e.code);
      throw Exception(SettingsService.instance.tr('formats_unreadable'));
    } on Exception catch (e) {
      // engine_no_formats is already localized — pass it through;
      // anything else becomes the generic message.
      final noFormats = SettingsService.instance.tr('engine_no_formats');
      if (e.toString().contains(noFormats)) rethrow;
      log.error(LogCategory.engine, 'Could not get video info',
          sanitizeEngineText(e.toString()));
      throw Exception(SettingsService.instance.tr('formats_unreadable'));
    }
  }

  /// One fetch attempt. Returns null when the service answered with no
  /// data; throws PlatformException (notably FORMATS) on failure.
  Future<VideoInfo?> _fetchInfoOnce(String url) async {
    final jsonStr =
        await _method.invokeMethod<String>('fetchFormats', {'url': url});
    if (jsonStr == null || jsonStr.isEmpty) return null;
    final j = jsonDecode(jsonStr) as Map<String, dynamic>;
    final title = (j['title'] as String?) ?? '';
    final duration = (j['duration'] as num?)?.toInt() ?? 0;
    final formats = (j['formats'] as List?) ?? const [];
    final options = _buildOptions(j, formats);
    final thumb = _pickThumbnail(j['thumbnails'] as List?);
    final stream = _pickStreamUrl(formats);
    LogService.instance.add(LogCategory.engine,
        'Info ready: "$title" (${options.length} options)');
    return VideoInfo(
      title: title,
      durationSeconds: duration,
      thumbnailUrl: thumb,
      streamUrl: stream,
      formats: options,
    );
  }

  /// Update the download tool at most once per session from the fetch
  /// path. Returns true only when a NEW tool version was installed —
  /// only then is retrying the fetch worthwhile (an up-to-date tool
  /// would fail the same way again; a failed update leaves the
  /// bundled version in place, so the next fetch may try again).
  Future<bool> _updateToolOnce() async {
    if (_toolUpdateAttempted) return false;
    final result = await updateTool();
    if (result != ToolUpdateResult.failed) _toolUpdateAttempted = true;
    return result == ToolUpdateResult.done;
  }

  /// Background cadence: first run ever, then at most once a week.
  /// Never blocks the caller; a failed update never breaks downloads.
  Future<void> maybeAutoUpdateTool() async {
    if (!isUpdateDue(SettingsService.instance.toolLastCheckMs,
        DateTime.now().millisecondsSinceEpoch)) {
      return;
    }
    await updateTool();
  }

  /// Update the download tool to its latest release (on-demand, e.g.
  /// from Settings → Updates). Concurrent callers share one attempt.
  /// The last-check timestamp is recorded only on success, so an
  /// offline failure is retried on the next launch instead of waiting
  /// a week.
  Future<ToolUpdateResult> updateTool() async {
    if (!await init()) return ToolUpdateResult.failed;
    if (_toolUpdateRunning != null) return _toolUpdateRunning!;
    final fut = _updateToolImpl();
    _toolUpdateRunning = fut;
    try {
      return await fut;
    } finally {
      _toolUpdateRunning = null;
    }
  }

  Future<ToolUpdateResult> _updateToolImpl() async {
    final log = LogService.instance;
    try {
      final res = await _method
          .invokeMapMethod<String, String>('updateTool')
          .timeout(const Duration(seconds: 90));
      final status = res?['status'];
      if (status == 'done') {
        _toolUpdateAttempted = true;
        await SettingsService.instance.setToolLastCheck(DateTime.now());
        log.add(LogCategory.update, 'Download tool updated');
        return ToolUpdateResult.done;
      }
      if (status == 'up_to_date') {
        _toolUpdateAttempted = true;
        await SettingsService.instance.setToolLastCheck(DateTime.now());
        log.add(LogCategory.update, 'Download tool already up to date');
        return ToolUpdateResult.upToDate;
      }
      log.error(
          LogCategory.update, 'Download tool update failed', 'bad status');
      return ToolUpdateResult.failed;
    } on TimeoutException {
      log.error(
          LogCategory.update, 'Download tool update failed', 'timed out');
      return ToolUpdateResult.failed;
    } on PlatformException catch (e) {
      // The native message is already sanitized; log the code only.
      log.error(LogCategory.update, 'Download tool update failed', e.code);
      return ToolUpdateResult.failed;
    } catch (e) {
      log.error(LogCategory.update, 'Download tool update failed',
          sanitizeEngineText(e.toString()));
      return ToolUpdateResult.failed;
    }
  }

  /// A mid-size thumbnail URL (prefers ~640px wide), or '' if none.
  String _pickThumbnail(List? thumbs) {
    if (thumbs == null || thumbs.isEmpty) return '';
    String best = '';
    var bestScore = 1 << 30;
    for (final raw in thumbs) {
      final t = raw as Map<String, dynamic>;
      final u = (t['url'] as String?) ?? '';
      if (u.isEmpty) continue;
      final w = (t['width'] as num?)?.toInt() ?? 0;
      final score = (w - 640).abs();
      if (score < bestScore) {
        bestScore = score;
        best = u;
      }
    }
    return best;
  }

  /// Best single-file stream URL (video+audio in one file, mp4 preferred)
  /// for the optional in-app preview player. '' when none is directly
  /// playable (then the card's play button stays hidden).
  String _pickStreamUrl(List formats) {
    String best = '';
    var bestHeight = -1;
    for (final raw in formats) {
      final f = raw as Map<String, dynamic>;
      final vcodec = (f['vcodec'] as String?) ?? 'none';
      final acodec = (f['acodec'] as String?) ?? 'none';
      final u = (f['url'] as String?) ?? '';
      if (vcodec == 'none' || acodec == 'none' || u.isEmpty) continue;
      final h = (f['height'] as num?)?.toInt() ?? 0;
      final ext = (f['ext'] as String?) ?? '';
      // Prefer mp4, then the tallest stream.
      final score = h + (ext == 'mp4' ? 10000 : 0);
      if (score > bestHeight) {
        bestHeight = score;
        best = u;
      }
    }
    return best;
  }

  List<FormatOption> _buildOptions(
      Map<String, dynamic> info, List formats) {
    String sizeText(dynamic f) {
      final size = (f['filesize'] as num?) ?? (f['filesize_approx'] as num?);
      if (size == null) return '—';
      final bytes = size.toInt();
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    final video = <Map<String, dynamic>>[];
    final audio = <Map<String, dynamic>>[];
    for (final raw in formats) {
      final f = raw as Map<String, dynamic>;
      final vcodec = (f['vcodec'] as String?) ?? 'none';
      final acodec = (f['acodec'] as String?) ?? 'none';
      final ext = (f['ext'] as String?) ?? '';
      if (vcodec == 'none' && acodec != 'none') {
        audio.add(f);
      } else if (vcodec != 'none' && ext.isNotEmpty) {
        video.add(f);
      }
    }

    final options = <FormatOption>[];

    // Highest: best video+audio merged.
    options.add(FormatOption(
      id: 'bestvideo+bestaudio/best',
      label: 'Highest',
      detail: 'Best video + best audio, merged to MP4',
      isAudioOnly: false,
      height: 4320,
      sizeText: '—',
    ));

    // Per-height best options: 2160 / 1080 / 720 / 480 / 360.
    final byHeight = <int, Map<String, dynamic>>{};
    for (final f in video) {
      final h = (f['height'] as num?)?.toInt() ?? 0;
      if (h <= 0) continue;
      final prev = byHeight[h];
      final prevSize = (prev?['filesize'] as num?) ?? 0;
      final size = (f['filesize'] as num?) ?? 0;
      if (prev == null || size > prevSize) byHeight[h] = f;
    }
    const wanted = [2160, 1080, 720, 480, 360];
    for (final h in wanted) {
      final f = byHeight[h];
      if (f == null) continue;
      final label = h >= 2160 ? '4K' : '${h}p';
      final ext = (f['ext'] as String?) ?? 'mp4';
      options.add(FormatOption(
        id: 'bestvideo[height<=$h]+bestaudio/best[height<=$h]',
        label: label,
        detail:
            '$ext · ${f['width'] ?? ''}×$h · ${sizeText(f)}',
        isAudioOnly: false,
        height: h,
        sizeText: sizeText(f),
      ));
    }

    // Lowest.
    options.add(FormatOption(
      id: 'worstvideo+worstaudio/worst',
      label: 'Lowest',
      detail: 'Smallest file, fastest download',
      isAudioOnly: false,
      height: 144,
      sizeText: '—',
    ));

    // Audio-only MP3.
    if (audio.isNotEmpty) {
      options.add(FormatOption(
        id: '__audio_mp3__',
        label: 'Audio MP3',
        detail: 'Sound only, converted to MP3',
        isAudioOnly: true,
        height: 0,
        sizeText: '—',
      ));
    }
    return options;
  }

  Future<void> startDownload({
    required String id,
    required String url,
    required String formatId,
    required bool audioOnly,
  }) async {
    // v1.0.1: lazy start — the download service only starts when a real
    // download begins, never at app launch.
    if (!await init()) {
      throw Exception(SettingsService.instance.tr('engine_unavailable'));
    }
    await _method.invokeMethod('startDownload', {
      'id': id,
      'url': url,
      'formatId': formatId,
      'audioOnly': audioOnly,
    });
  }

  Future<void> pauseDownload(String id) async {
    await _method.invokeMethod('pauseDownload', {'id': id});
  }

  Future<void> resumeDownload({
    required String id,
    required String url,
    required String formatId,
    required bool audioOnly,
  }) async {
    // v1.0.1: lazy start — same guard as startDownload.
    if (!await init()) {
      throw Exception(SettingsService.instance.tr('engine_unavailable'));
    }
    await _method.invokeMethod('resumeDownload', {
      'id': id,
      'url': url,
      'formatId': formatId,
      'audioOnly': audioOnly,
    });
  }

  Future<void> cancelDownload(String id) async {
    await _method.invokeMethod('cancelDownload', {'id': id});
  }

  Future<bool> openFile(String path) async {
    try {
      final ok = await _method.invokeMethod<bool>('openFile', {'path': path});
      return ok ?? false;
    } catch (e) {
      LogService.instance
          .error(LogCategory.storage, 'Open file failed', e.toString());
      return false;
    }
  }

  Future<String> downloadDir() async {
    try {
      final dir = await _method.invokeMethod<String>('downloadDir');
      return dir ?? '';
    } catch (_) {
      return '';
    }
  }

  void dispose() {
    _sub?.cancel();
    _progressController.close();
  }
}

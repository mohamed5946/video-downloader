import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models.dart';
import 'log_service.dart';
import 'settings_service.dart';

/// Bridge to the native yt-dlp engine (youtubedl-android, Maven Central
/// io.github.junkfood02.youtubedl-android 0.18.1 — CPython 3.11 + yt-dlp
/// bundled as native .so per ABI, same engine Seal / YTDLnis use).
///
/// The official yt-dlp Linux aarch64 binary is dynamically linked against
/// glibc and CANNOT run on Android — that is why the app uses the
/// youtubedl-android library instead of a raw binary.
class EngineService {
  EngineService._();

  static final EngineService instance = EngineService._();

  static const _method = MethodChannel('com.valor.snapdl/engine');
  static const _events = EventChannel('com.valor.snapdl/engine_events');

  bool _initialized = false;
  String _engineVersion = '';
  StreamSubscription? _sub;

  bool get initialized => _initialized;
  String get engineVersion => _engineVersion;

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
        LogService.instance.error(LogCategory.engine,
            'Download service failed to start',
            '${e.code}: ${e.message} | ${e.details}');
      } catch (e) {
        LogService.instance
            .error(LogCategory.engine, 'Download service failed to start', e.toString());
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
  Future<VideoInfo> fetchInfo(String url) async {
    final log = LogService.instance;
    if (!await init()) {
      throw Exception(SettingsService.instance.tr('engine_unavailable'));
    }
    log.add(LogCategory.engine, 'Getting video info', url);
    try {
      final jsonStr =
          await _method.invokeMethod<String>('fetchFormats', {'url': url});
      if (jsonStr == null || jsonStr.isEmpty) {
        throw Exception(SettingsService.instance.tr('engine_no_formats'));
      }
      final j = jsonDecode(jsonStr) as Map<String, dynamic>;
      final title = (j['title'] as String?) ?? '';
      final duration = (j['duration'] as num?)?.toInt() ?? 0;
      final formats = (j['formats'] as List?) ?? const [];
      final options = _buildOptions(j, formats);
      final thumb = _pickThumbnail(j['thumbnails'] as List?);
      final stream = _pickStreamUrl(formats);
      log.add(LogCategory.engine,
          'Info ready: "$title" (${options.length} options)');
      return VideoInfo(
        title: title,
        durationSeconds: duration,
        thumbnailUrl: thumb,
        streamUrl: stream,
        formats: options,
      );
    } catch (e) {
      log.error(LogCategory.engine, 'Could not get video info', e.toString());
      rethrow;
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

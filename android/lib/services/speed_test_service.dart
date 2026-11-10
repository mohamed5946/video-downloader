import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Internet speed test — plain HTTP timing against Cloudflare's speed
/// test endpoints. No third-party speed-test SDK, no ads/trackers, no
/// extra permissions (INTERNET is already declared).
///
/// Data-conscious by design (v1.0.4): download ~10 MB, upload ~2 MB —
/// enough for a stable reading on typical mobile speeds without burning
/// the user's mobile data. The test NEVER runs on its own: the screen
/// only starts it when the user taps the button.
enum SpeedTestPhase { idle, ping, download, upload, done, error }

class SpeedTestService extends ChangeNotifier {
  SpeedTestService._();

  static final SpeedTestService instance = SpeedTestService._();

  static const _pingUrl = 'https://speed.cloudflare.com/__down?bytes=0';
  static const _downUrl =
      'https://speed.cloudflare.com/__down?bytes=10000000';
  static const _upUrl = 'https://speed.cloudflare.com/__up';

  static const int downloadBytes = 10000000; // ~10 MB
  static const int uploadBytes = 2 * 1024 * 1024; // ~2 MB

  SpeedTestPhase phase = SpeedTestPhase.idle;
  double? downloadMbps;
  double? uploadMbps;
  double? pingMs;
  double progress = 0; // 0.0 – 1.0 across the whole test
  String? error;
  bool get running =>
      phase == SpeedTestPhase.ping ||
      phase == SpeedTestPhase.download ||
      phase == SpeedTestPhase.upload;

  http.Client? _client;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
    _client?.close();
  }

  void reset() {
    _cancelled = false;
    phase = SpeedTestPhase.idle;
    downloadMbps = null;
    uploadMbps = null;
    pingMs = null;
    progress = 0;
    error = null;
    notifyListeners();
  }

  Future<void> run() async {
    if (running) return;
    _cancelled = false;
    error = null;
    downloadMbps = null;
    uploadMbps = null;
    pingMs = null;
    progress = 0;
    _client = http.Client();
    try {
      phase = SpeedTestPhase.ping;
      notifyListeners();
      pingMs = await _measurePing();
      if (_cancelled) return;

      phase = SpeedTestPhase.download;
      notifyListeners();
      downloadMbps = await _measureDownload();
      if (_cancelled) return;

      phase = SpeedTestPhase.upload;
      progress = 0.66;
      notifyListeners();
      uploadMbps = await _measureUpload();
      if (_cancelled) return;

      progress = 1;
      phase = SpeedTestPhase.done;
    } catch (e) {
      if (_cancelled) return;
      error = e.toString();
      phase = SpeedTestPhase.error;
    } finally {
      _client?.close();
      _client = null;
      notifyListeners();
    }
  }

  /// Fastest of 3 tiny round trips, in milliseconds.
  Future<double> _measurePing() async {
    final client = _client!;
    double? best;
    for (var i = 0; i < 3; i++) {
      if (_cancelled) throw const _Cancelled();
      final stopwatch = Stopwatch()..start();
      final resp = await client
          .get(Uri.parse(_pingUrl))
          .timeout(const Duration(seconds: 10));
      stopwatch.stop();
      if (resp.statusCode != 200) {
        throw Exception('Ping failed (HTTP ${resp.statusCode})');
      }
      final ms = stopwatch.elapsedMilliseconds.toDouble();
      best = best == null ? ms : min(best, ms);
    }
    return best ?? 0;
  }

  /// Stream ~10 MB down and time it. Progress is reported live.
  Future<double> _measureDownload() async {
    final client = _client!;
    final request = http.Request('GET', Uri.parse(_downUrl));
    final stopwatch = Stopwatch()..start();
    final streamed = await client
        .send(request)
        .timeout(const Duration(seconds: 60));
    if (streamed.statusCode != 200) {
      throw Exception('Download failed (HTTP ${streamed.statusCode})');
    }
    var received = 0;
    await for (final chunk in streamed.stream) {
      if (_cancelled) throw const _Cancelled();
      received += chunk.length;
      // Download is the middle third of the whole test.
      progress = 0.33 * (received / downloadBytes).clamp(0.0, 1.0);
      notifyListeners();
    }
    stopwatch.stop();
    final seconds = stopwatch.elapsedMilliseconds / 1000;
    if (seconds <= 0 || received == 0) {
      throw Exception('Download returned no data');
    }
    return received * 8 / seconds / 1e6; // Mbps
  }

  /// POST ~2 MB up and time it.
  Future<double> _measureUpload() async {
    final client = _client!;
    final body = List<int>.filled(uploadBytes, 0);
    final stopwatch = Stopwatch()..start();
    final resp = await client
        .post(Uri.parse(_upUrl), body: body)
        .timeout(const Duration(seconds: 60));
    stopwatch.stop();
    if (resp.statusCode != 200) {
      throw Exception('Upload failed (HTTP ${resp.statusCode})');
    }
    final seconds = stopwatch.elapsedMilliseconds / 1000;
    if (seconds <= 0) throw Exception('Upload returned no data');
    return uploadBytes * 8 / seconds / 1e6; // Mbps
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

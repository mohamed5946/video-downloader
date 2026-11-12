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
///
/// v1.0.7: live instantaneous samples (the gauge needle moves while
/// data flows, not just at the end), jitter from the 3 ping samples,
/// and pure helpers (formatSpeed / gaugeFraction / computeJitter) so
/// the display math is unit-testable without platform channels.
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

  /// At most this long between live samples (the gauge updates at
  /// least this often while data flows).
  static const Duration sampleInterval = Duration(milliseconds: 250);

  SpeedTestPhase phase = SpeedTestPhase.idle;
  double? downloadMbps;
  double? uploadMbps;
  double? pingMs;
  // v1.0.7: jitter = mean absolute difference between successive ping
  // samples, in milliseconds. Null until the ping phase completes.
  double? jitterMs;
  // v1.0.7: live instantaneous speed (Mbps) during download/upload —
  // the gauge needle follows this, then rests on the final average.
  double currentMbps = 0;
  double progress = 0; // 0.0 – 1.0 across the whole test
  String? error;
  bool get running =>
      phase == SpeedTestPhase.ping ||
      phase == SpeedTestPhase.download ||
      phase == SpeedTestPhase.upload;

  /// v1.0.7: alias the screen reads to know which phase the live
  /// value belongs to (download needle vs upload needle).
  SpeedTestPhase get currentPhase => phase;

  /// v1.0.7: the raw ping samples (ms), fastest-of-3 is [pingMs].
  List<double> get pingSamples => List.unmodifiable(_pingSamples);
  final List<double> _pingSamples = [];

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
    jitterMs = null;
    _pingSamples.clear();
    currentMbps = 0;
    progress = 0;
    error = null;
    notifyListeners();
  }

  /// Format a speed for display in the selected unit.
  /// 'Mbps' shows the value as-is; 'MB/s' divides by 8. One decimal.
  static String formatSpeed(double mbps, String unit) {
    if (unit == 'MB/s') {
      return '${(mbps / 8).toStringAsFixed(1)} MB/s';
    }
    return '${mbps.toStringAsFixed(1)} Mbps';
  }

  /// Map 0–1000 Mbps to 0.0–1.0 on the gauge dial. The dial marks are
  /// 0, 5, 10, 50, 100, 200, 500, 750, 1000, placed at EQUAL arc
  /// spacing (v1.0.8, Ookla-style): piecewise-linear between adjacent
  /// marks, so mark i sits at fraction i/8 and 100 sits at the exact
  /// middle / top-center of the dial (fraction 0.5).
  static const List<double> gaugeMarks = [
    0, 5, 10, 50, 100, 200, 500, 750, 1000
  ];

  static double gaugeFraction(double mbps) {
    if (mbps <= 0) return 0;
    if (mbps >= 1000) return 1;
    for (var i = 0; i < gaugeMarks.length - 1; i++) {
      final lo = gaugeMarks[i];
      final hi = gaugeMarks[i + 1];
      if (mbps <= hi) {
        return (i + (mbps - lo) / (hi - lo)) / (gaugeMarks.length - 1);
      }
    }
    return 1;
  }

  /// Jitter: mean absolute difference between successive ping samples.
  /// Fewer than 2 samples → 0 (nothing to compare).
  static double computeJitter(List<double> samples) {
    if (samples.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < samples.length; i++) {
      total += (samples[i] - samples[i - 1]).abs();
    }
    return total / (samples.length - 1);
  }

  Future<void> run() async {
    if (running) return;
    _cancelled = false;
    error = null;
    downloadMbps = null;
    uploadMbps = null;
    pingMs = null;
    jitterMs = null;
    _pingSamples.clear();
    currentMbps = 0;
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
      currentMbps = downloadMbps ?? 0;
      if (_cancelled) return;

      phase = SpeedTestPhase.upload;
      progress = 0.66;
      notifyListeners();
      uploadMbps = await _measureUpload();
      currentMbps = uploadMbps ?? 0;
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

  /// Fastest of 3 tiny round trips, in milliseconds. Keeps all 3
  /// samples so jitter can be computed from their spread.
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
      _pingSamples.add(ms);
      best = best == null ? ms : min(best, ms);
    }
    jitterMs = computeJitter(_pingSamples);
    return best ?? 0;
  }

  /// Stream ~10 MB down and time it. Progress is reported live, and
  /// [currentMbps] is refreshed at least every 250 ms from the bytes
  /// received in the last window, so the gauge needle moves live.
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
    final sampler = _LiveSampler(onSample: (mbps) {
      currentMbps = mbps;
      notifyListeners();
    });
    await for (final chunk in streamed.stream) {
      if (_cancelled) throw const _Cancelled();
      received += chunk.length;
      sampler.add(chunk.length);
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

  /// POST ~2 MB up, streamed in 64 KB chunks so the live speed can
  /// be sampled while the upload flows (a single post() call would
  /// only report a final average).
  Future<double> _measureUpload() async {
    final client = _client!;
    final stopwatch = Stopwatch()..start();
    var sent = 0;
    final sampler = _LiveSampler(onSample: (mbps) {
      currentMbps = mbps;
      // Upload is the last third of the whole test.
      progress = 0.66 + 0.34 * (sent / uploadBytes).clamp(0.0, 1.0);
      notifyListeners();
    });
    const chunkSize = 64 * 1024;
    final chunk = List<int>.filled(chunkSize, 0);
    Stream<List<int>> body() async* {
      while (sent < uploadBytes) {
        if (_cancelled) throw const _Cancelled();
        final n = min(chunkSize, uploadBytes - sent);
        sent += n;
        sampler.add(n);
        yield n == chunkSize ? chunk : chunk.sublist(0, n);
      }
    }

    final request = http.StreamedRequest('POST', Uri.parse(_upUrl));
    request.contentLength = uploadBytes;
    final responseFuture = client.send(request);
    try {
      await request.sink.addStream(body());
      await request.sink.close();
    } catch (e) {
      // A body-stream error (e.g. cancel) also fails the pending
      // send future — swallow it here so it never surfaces as an
      // unhandled async error; the caller already sees this throw.
      await responseFuture.then<void>((_) {}, onError: (_) {});
      rethrow;
    }
    final streamed =
        await responseFuture.timeout(const Duration(seconds: 60));
    if (streamed.statusCode != 200) {
      throw Exception('Upload failed (HTTP ${streamed.statusCode})');
    }
    // Drain the (tiny) response body so the request fully completes.
    await streamed.stream.toList();
    stopwatch.stop();
    final seconds = stopwatch.elapsedMilliseconds / 1000;
    if (seconds <= 0) throw Exception('Upload returned no data');
    return uploadBytes * 8 / seconds / 1e6; // Mbps
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

/// Turns a stream of byte counts into a live Mbps reading: emits the
/// window average at most every [SpeedTestService.sampleInterval]
/// (250 ms) — often enough for a smooth needle, seldom enough to
/// flood listeners.
class _LiveSampler {
  _LiveSampler({required this.onSample});

  final void Function(double mbps) onSample;

  DateTime _windowStart = DateTime.now();
  int _windowBytes = 0;

  void add(int bytes) {
    _windowBytes += bytes;
    final now = DateTime.now();
    final elapsed = now.difference(_windowStart);
    if (elapsed >= SpeedTestService.sampleInterval && elapsed.inMilliseconds > 0) {
      final seconds = elapsed.inMilliseconds / 1000;
      onSample(_windowBytes * 8 / seconds / 1e6);
      _windowStart = now;
      _windowBytes = 0;
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models.dart';
import 'log_service.dart';
import 'settings_service.dart';

/// In-app updates, same pattern as DeliveryFlow / Store Admin:
/// a manifest JSON hosted on the GitHub releases page.
class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();

  /// Same engine channel MainActivity listens on ("installUpdate"
  /// lives next to "updateTool" / "openFile" there).
  static const _engine = MethodChannel('com.valor.snapdl/engine');

  /// Single constant — the repo will be created at delivery.
  static const manifestUrl =
      'https://github.com/mohamed5946/video-downloader/releases/latest/download/update.json';

  static const portfolioUrl = 'https://mohamed5946.github.io/portfolio/';

  Future<UpdateCheck> checkForUpdate() async {
    final log = LogService.instance;
    try {
      final info = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(info.buildNumber) ?? 0;
      log.add(LogCategory.update,
          'Checking for updates (current ${info.version}+$currentCode)');
      final res = await http.get(Uri.parse(manifestUrl)).timeout(
            const Duration(seconds: 20),
          );
      if (res.statusCode != 200) {
        log.error(LogCategory.update, 'Update check failed',
            'HTTP ${res.statusCode} from manifest URL');
        return UpdateCheck(
          available: false,
          error: SettingsService.instance.trf('update_http_error', {'code': res.statusCode.toString()}),
        );
      }
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final latestCode = (j['versionCode'] as num?)?.toInt() ?? 0;
      final latestVersion = (j['version'] as String?) ?? '';
      final apkUrl = (j['apkUrl'] as String?) ?? '';
      final notes = (j['notes'] as String?) ?? '';
      // v1.0.7: APK size for the update card (manifest 'apkSizeBytes',
      // 0 when the manifest does not carry it).
      final sizeBytes = (j['apkSizeBytes'] as num?)?.toInt() ?? 0;
      if (latestCode > currentCode) {
        log.add(LogCategory.update,
            'Update available: $latestVersion+$latestCode');
        return UpdateCheck(
          available: true,
          version: latestVersion,
          versionCode: latestCode,
          apkUrl: apkUrl,
          notes: notes,
          sizeBytes: sizeBytes,
        );
      }
      log.add(LogCategory.update, 'App is up to date');
      return const UpdateCheck(available: false);
    } catch (e) {
      log.error(LogCategory.update, 'Update check failed', e.toString());
      return UpdateCheck(
        available: false,
        error: SettingsService.instance.tr('update_no_internet'),
      );
    }
  }

  /// v1.0.7: download the update APK inside the app (no external
  /// browser), streaming to disk and reporting live progress at
  /// least every 250 ms: percent, instantaneous speed and ETA.
  /// Returns the downloaded file. Throws a sanitized generic message
  /// on failure — never a URL or a library name (same rule as the
  /// engine sanitize in v1.0.5).
  ///
  /// The file lands in the app's external files directory
  /// (SnapDL-update.apk): that directory is covered by the
  /// FileProvider paths, so MainActivity "installUpdate" can hand it
  /// to the system installer. The internal documents directory is NOT
  /// in file_paths.xml, so an APK there could not be shared.
  Future<File> downloadUpdate({
    required String url,
    required int totalBytes,
    required void Function(UpdateDownloadProgress) onProgress,
  }) async {
    final log = LogService.instance;
    final dir = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/SnapDL-update.apk');
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final streamed =
          await client.send(request).timeout(const Duration(seconds: 30));
      if (streamed.statusCode != 200) {
        throw Exception('Update download failed');
      }
      final total = totalBytes > 0
          ? totalBytes
          : (streamed.contentLength ?? 0);
      final sink = file.openWrite();
      var received = 0;
      var windowBytes = 0;
      var windowStart = DateTime.now();
      var lastReport = DateTime.now();
      try {
        await for (final chunk in streamed.stream) {
          sink.add(chunk);
          received += chunk.length;
          windowBytes += chunk.length;
          final now = DateTime.now();
          if (now.difference(lastReport) >=
              const Duration(milliseconds: 250)) {
            final windowSeconds =
                now.difference(windowStart).inMilliseconds / 1000;
            final speedBps =
                windowSeconds > 0 ? windowBytes / windowSeconds : 0.0;
            onProgress(UpdateDownloadProgress.compute(
              received: received,
              total: total,
              speedBps: speedBps,
            ));
            windowBytes = 0;
            windowStart = now;
            lastReport = now;
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      // Final report at 100% (or whatever arrived when total is
      // unknown) so the card never sticks below the real end.
      onProgress(UpdateDownloadProgress.compute(
        received: received,
        total: total,
        speedBps: 0,
      ));
      log.add(LogCategory.update,
          'Update downloaded (${received} bytes)');
      return file;
    } catch (e) {
      // Never leak the URL or the HTTP library's wording to the UI.
      log.error(LogCategory.update, 'Update download failed', 'download');
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      throw Exception(
          SettingsService.instance.tr('updates_download_failed'));
    } finally {
      client.close();
    }
  }

  /// v1.0.7: ask the system installer to install a downloaded APK
  /// (native "installUpdate" — FileProvider URI + ACTION_VIEW).
  /// Returns true when the installer was launched.
  Future<bool> installUpdate(String path) async {
    try {
      final ok = await _engine.invokeMethod<bool>(
          'installUpdate', {'path': path});
      return ok ?? false;
    } catch (e) {
      LogService.instance.error(
          LogCategory.update, 'Install failed', 'install');
      return false;
    }
  }
}

class UpdateCheck {
  const UpdateCheck({
    required this.available,
    this.version,
    this.versionCode,
    this.apkUrl,
    this.notes,
    this.error,
    this.sizeBytes = 0,
  });

  final bool available;
  final String? version;
  final int? versionCode;
  final String? apkUrl;
  final String? notes;
  final String? error;
  // v1.0.7: APK size in bytes from the manifest ('apkSizeBytes'),
  // 0 when the manifest does not carry it.
  final int sizeBytes;
}

/// v1.0.7: one live snapshot of an in-app update download.
/// Pure value class — [compute] is unit-testable without network.
class UpdateDownloadProgress {
  const UpdateDownloadProgress({
    required this.received,
    required this.total,
    required this.percent,
    required this.speedBps,
    required this.etaSeconds,
  });

  /// Bytes received so far.
  final int received;

  /// Total bytes (0 when unknown — e.g. no Content-Length).
  final int total;

  /// 0.0 – 1.0. Always 0 when [total] is 0.
  final double percent;

  /// Instantaneous download speed, bytes per second (0 = unknown).
  final double speedBps;

  /// Estimated seconds left (0 when unknown or finished).
  final int etaSeconds;

  /// Pure derivation: percent from received/total, ETA from the
  /// remaining bytes at the current speed. total == 0 → percent 0,
  /// eta 0. speed <= 0 → eta 0 (unknown, not infinite).
  static UpdateDownloadProgress compute({
    required int received,
    required int total,
    required double speedBps,
  }) {
    final percent =
        total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
    final eta = total > 0 && speedBps > 0 && received < total
        ? ((total - received) / speedBps).ceil()
        : 0;
    return UpdateDownloadProgress(
      received: received,
      total: total,
      percent: percent,
      speedBps: speedBps,
      etaSeconds: eta,
    );
  }

  /// Human speed for the card, e.g. 2.4 MB/s or 850 KB/s.
  String get speedText {
    if (speedBps <= 0) return '—';
    if (speedBps >= 1024 * 1024) {
      return '${(speedBps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    if (speedBps >= 1024) {
      return '${(speedBps / 1024).toStringAsFixed(0)} KB/s';
    }
    return '${speedBps.toStringAsFixed(0)} B/s';
  }

  /// ETA as mm:ss (e.g. 01:23). 0 → 00:00.
  String get etaText {
    final m = etaSeconds ~/ 60;
    final s = etaSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

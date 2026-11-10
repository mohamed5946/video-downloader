import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../models.dart';
import 'log_service.dart';
import 'settings_service.dart';

/// In-app updates, same pattern as DeliveryFlow / Store Admin:
/// a manifest JSON hosted on the GitHub releases page.
class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();

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
      if (latestCode > currentCode) {
        log.add(LogCategory.update,
            'Update available: $latestVersion+$latestCode');
        return UpdateCheck(
          available: true,
          version: latestVersion,
          versionCode: latestCode,
          apkUrl: apkUrl,
          notes: notes,
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
}

class UpdateCheck {
  const UpdateCheck({
    required this.available,
    this.version,
    this.versionCode,
    this.apkUrl,
    this.notes,
    this.error,
  });

  final bool available;
  final String? version;
  final int? versionCode;
  final String? apkUrl;
  final String? notes;
  final String? error;
}

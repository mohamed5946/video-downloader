import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'strings.dart';

/// App-wide settings, persisted in SharedPreferences and applied
/// immediately (theme, language, download prefs, update prefs).
class SettingsService extends ChangeNotifier {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  static const _kLang = 'snapdl_lang'; // en | ar
  static const _kThemeMode = 'snapdl_theme_mode'; // light | dark | system
  static const _kDefaultQuality = 'snapdl_default_quality';
  static const _kWifiOnly = 'snapdl_wifi_only';
  static const _kMaxSimultaneous = 'snapdl_max_simultaneous';
  static const _kDownloadLocation = 'snapdl_download_location'; // public | app
  static const _kAutoCheck = 'snapdl_auto_check_updates';
  // v1.0.5: last successful download-tool update, epoch ms (0 = never).
  static const _kToolLastCheck = 'snapdl_tool_last_check';
  // v1.0.7: speed-test unit ('Mbps' | 'MB/s'), tonight-update flag and
  // the path of a downloaded-but-not-installed update APK.
  static const _kSpeedUnit = 'snapdl_speed_unit';
  static const _kUpdateTonight = 'snapdl_update_tonight';
  static const _kPendingUpdatePath = 'snapdl_pending_update_path';

  String language = 'ar';
  // v1.0.4: real theme preference. Default 'light' preserves the
  // current look; 'dark' is night mode, 'system' follows the device.
  String themeMode = 'light';
  String defaultQuality = 'Highest';
  bool wifiOnly = false;
  int maxSimultaneous = 1;
  String downloadLocation = 'public';
  bool autoCheckUpdates = true;
  // v1.0.5: 0 = the download tool was never updated.
  int toolLastCheckMs = 0;
  // v1.0.7: speed-test display unit, default Mbps.
  String speedUnit = 'Mbps';
  // v1.0.7: user asked to install the pending update tonight.
  bool updateTonight = false;
  // v1.0.7: downloaded update APK waiting for install ('' = none).
  String pendingUpdatePath = '';

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    language = prefs.getString(_kLang) ?? 'ar';
    themeMode = prefs.getString(_kThemeMode) ?? 'light';
    if (themeMode != 'light' &&
        themeMode != 'dark' &&
        themeMode != 'system') {
      themeMode = 'light';
    }
    defaultQuality = prefs.getString(_kDefaultQuality) ?? 'Highest';
    wifiOnly = prefs.getBool(_kWifiOnly) ?? false;
    maxSimultaneous = prefs.getInt(_kMaxSimultaneous) ?? 1;
    downloadLocation = prefs.getString(_kDownloadLocation) ?? 'public';
    autoCheckUpdates = prefs.getBool(_kAutoCheck) ?? true;
    toolLastCheckMs = prefs.getInt(_kToolLastCheck) ?? 0;
    speedUnit = prefs.getString(_kSpeedUnit) ?? 'Mbps';
    if (speedUnit != 'Mbps' && speedUnit != 'MB/s') speedUnit = 'Mbps';
    updateTonight = prefs.getBool(_kUpdateTonight) ?? false;
    pendingUpdatePath = prefs.getString(_kPendingUpdatePath) ?? '';
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLang, language);
    await prefs.setString(_kThemeMode, themeMode);
    await prefs.setString(_kDefaultQuality, defaultQuality);
    await prefs.setBool(_kWifiOnly, wifiOnly);
    await prefs.setInt(_kMaxSimultaneous, maxSimultaneous);
    await prefs.setString(_kDownloadLocation, downloadLocation);
    await prefs.setBool(_kAutoCheck, autoCheckUpdates);
    await prefs.setInt(_kToolLastCheck, toolLastCheckMs);
    await prefs.setString(_kSpeedUnit, speedUnit);
    await prefs.setBool(_kUpdateTonight, updateTonight);
    await prefs.setString(_kPendingUpdatePath, pendingUpdatePath);
  }

  /// Localised string for [key] in the current language.
  String tr(String key) {
    final map = AppStrings.mapFor(language);
    return map[key] ?? AppStrings.mapFor('en')[key] ?? key;
  }

  /// Localised string with {name} placeholders replaced.
  String trf(String key, Map<String, String> params) {
    var s = tr(key);
    params.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  /// Display label for a format option key in the current language.
  String qualityLabel(String label) =>
      AppStrings.qualityDisplay(label, language);

  /// Display detail for a format option key in the current language.
  String qualityDetail(String label, String fallback) =>
      AppStrings.qualityDetail(label, language, fallback);

  Future<void> setLanguage(String lang) async {
    language = lang;
    notifyListeners();
    await _save();
  }

  /// Flutter ThemeMode for the persisted preference.
  ThemeMode get themeModeEnum {
    switch (themeMode) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  Future<void> setThemeMode(String mode) async {
    if (mode != 'light' && mode != 'dark' && mode != 'system') return;
    themeMode = mode;
    notifyListeners();
    await _save();
  }

  Future<void> setDefaultQuality(String q) async {
    defaultQuality = q;
    notifyListeners();
    await _save();
  }

  Future<void> setWifiOnly(bool v) async {
    wifiOnly = v;
    notifyListeners();
    await _save();
  }

  Future<void> setMaxSimultaneous(int v) async {
    maxSimultaneous = v;
    notifyListeners();
    await _save();
  }

  Future<void> setDownloadLocation(String v) async {
    downloadLocation = v;
    notifyListeners();
    await _save();
  }

  Future<void> setAutoCheckUpdates(bool v) async {
    autoCheckUpdates = v;
    notifyListeners();
    await _save();
  }

  /// v1.0.7: speed-test display unit ('Mbps' | 'MB/s').
  Future<void> setSpeedUnit(String unit) async {
    if (unit != 'Mbps' && unit != 'MB/s') return;
    speedUnit = unit;
    notifyListeners();
    await _save();
  }

  /// v1.0.7: remember the user asked to install the update tonight.
  Future<void> setUpdateTonight(bool v) async {
    updateTonight = v;
    notifyListeners();
    await _save();
  }

  /// v1.0.7: remember a downloaded update APK waiting for install.
  Future<void> setPendingUpdatePath(String path) async {
    pendingUpdatePath = path;
    notifyListeners();
    await _save();
  }

  /// v1.0.5: record a successful download-tool update (drives the
  /// once-a-week background cadence in EngineService).
  Future<void> setToolLastCheck(DateTime when) async {
    toolLastCheckMs = when.millisecondsSinceEpoch;
    notifyListeners();
    await _save();
  }
}

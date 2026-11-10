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
  static const _kDefaultQuality = 'snapdl_default_quality';
  static const _kWifiOnly = 'snapdl_wifi_only';
  static const _kMaxSimultaneous = 'snapdl_max_simultaneous';
  static const _kDownloadLocation = 'snapdl_download_location'; // public | app
  static const _kAutoCheck = 'snapdl_auto_check_updates';

  String language = 'ar';
  String defaultQuality = 'Highest';
  bool wifiOnly = false;
  int maxSimultaneous = 1;
  String downloadLocation = 'public';
  bool autoCheckUpdates = true;

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    language = prefs.getString(_kLang) ?? 'ar';
    defaultQuality = prefs.getString(_kDefaultQuality) ?? 'Highest';
    wifiOnly = prefs.getBool(_kWifiOnly) ?? false;
    maxSimultaneous = prefs.getInt(_kMaxSimultaneous) ?? 1;
    downloadLocation = prefs.getString(_kDownloadLocation) ?? 'public';
    autoCheckUpdates = prefs.getBool(_kAutoCheck) ?? true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLang, language);
    await prefs.setString(_kDefaultQuality, defaultQuality);
    await prefs.setBool(_kWifiOnly, wifiOnly);
    await prefs.setInt(_kMaxSimultaneous, maxSimultaneous);
    await prefs.setString(_kDownloadLocation, downloadLocation);
    await prefs.setBool(_kAutoCheck, autoCheckUpdates);
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
}

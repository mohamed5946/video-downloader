import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models.dart';

/// In-app diagnostics log — categorized entries with exact failure reasons.
/// Standing build rule: every app ships with this from day one.
class LogService extends ChangeNotifier {
  LogService._();

  static final LogService instance = LogService._();

  final List<LogEntry> _entries = [];
  List<LogEntry> get entries => List.unmodifiable(_entries);

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/snapdl-log.json');
      if (await file.exists()) {
        final raw = await file.readAsString();
        final list = jsonDecode(raw) as List;
        _entries.addAll(
          list.map((e) => LogEntry.fromJson(e as Map<String, dynamic>)),
        );
        if (_entries.length > 500) {
          _entries.removeRange(0, _entries.length - 500);
        }
      }
    } catch (e) {
      // Logging must never crash the app; keep an in-memory note.
      _entries.add(LogEntry(
        time: DateTime.now(),
        category: LogCategory.ui,
        message: 'Log file could not be loaded',
        detail: e.toString(),
      ));
    }
    notifyListeners();
  }

  void add(LogCategory category, String message, [String? detail]) {
    _entries.add(LogEntry(
      time: DateTime.now(),
      category: category,
      message: message,
      detail: detail,
    ));
    if (_entries.length > 500) {
      _entries.removeRange(0, _entries.length - 500);
    }
    notifyListeners();
    _persist();
  }

  void info(LogCategory c, String m) => add(c, m);
  void error(LogCategory c, String m, [String? detail]) => add(c, m, detail);

  Future<void> _persist() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/snapdl-log.json');
      await file.writeAsString(jsonEncode(
        _entries.map((e) => e.toJson()).toList(),
      ));
    } catch (_) {
      // Silent: never crash on log persistence.
    }
  }

  Future<String> exportText() async {
    final buf = StringBuffer();
    for (final e in _entries) {
      buf.writeln(
          '[${e.timeText}] ${e.category.label}: ${e.message}${e.detail == null ? '' : ' — ${e.detail}'}');
    }
    return buf.toString();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
    _persist();
  }
}

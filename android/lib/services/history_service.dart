import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

/// Local download history, persisted in SharedPreferences.
class HistoryService extends ChangeNotifier {
  HistoryService._();

  static final HistoryService instance = HistoryService._();

  static const _key = 'snapdl_history_v1';

  final List<HistoryEntry> _items = [];
  List<HistoryEntry> get items => List.unmodifiable(_items);

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _items.addAll(
          list.map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>)),
        );
        _items.sort((a, b) => b.date.compareTo(a.date));
      } catch (_) {
        // Corrupt history: start fresh rather than crash.
        _items.clear();
      }
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> add(HistoryEntry entry) async {
    _items.removeWhere((e) => e.id == entry.id);
    _items.insert(0, entry);
    if (_items.length > 200) {
      _items.removeRange(200, _items.length);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    _items.clear();
    notifyListeners();
    await _persist();
  }
}

// lib/services/holiday_service.dart
import 'dart:convert';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../core/app_config.dart';

/// HolidayService（发布级正确架构）
/// - 不使用全局单例
/// - region / bundle 由外部注入（main.dart / Provider / tests）
class HolidayService {
  HolidayService({
    required this.region,
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle;

  final AppRegion region;
  final AssetBundle _bundle;

  /// region-year -> { "YYYY-MM-DD": "Holiday name" }
  final Map<String, Map<String, String>> _cache = {};

  Map<String, dynamic>? _manifest;

  Future<void> prefetchYears(Iterable<int> years) async {
    final set = years.toSet();
    for (final y in set) {
      await _loadYear(year: y);
    }
  }

  Future<String?> nameOf(DateTime day) async {
    final map = await _loadYear(year: day.year);
    return map[_key(day)];
  }

  Future<bool> isHoliday(DateTime day) async {
    final map = await _loadYear(year: day.year);
    return map.containsKey(_key(day));
  }

  void clearCache() {
    _cache.clear();
    _manifest = null;
  }

  // ---------------- internal ----------------

  String _regionFolder(AppRegion r) => r == AppRegion.tw ? 'tw' : 'jp';

  Future<Map<String, dynamic>> _loadManifest() async {
    if (_manifest != null) return _manifest!;

    try {
      final raw = await _bundle.loadString('AssetManifest.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _manifest = decoded;
        return decoded;
      }
    } catch (_) {
      // ignore
    }

    _manifest = <String, dynamic>{};
    return _manifest!;
  }

  Future<Map<String, String>> _loadYear({required int year}) async {
    final folder = _regionFolder(region);
    final cacheKey = '$folder-$year';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final path = 'assets/holidays/$folder/$year.json';

    // 发布级：manifest gate（不存在就返回空，不抛）
    final manifest = await _loadManifest();
    final exists = manifest[path] != null;
    if (!exists) {
      final empty = <String, String>{};
      _cache[cacheKey] = empty;
      return empty;
    }

    try {
      final raw = await _bundle.loadString(path);
      final decoded = jsonDecode(raw);

      final map = <String, String>{};
      if (decoded is Map) {
        for (final e in decoded.entries) {
          final k = e.key.toString().trim();
          final v = e.value.toString().trim();
          if (k.isNotEmpty && v.isNotEmpty) map[k] = v;
        }
      }

      _cache[cacheKey] = map;
      return map;
    } catch (_) {
      final empty = <String, String>{};
      _cache[cacheKey] = empty;
      return empty;
    }
  }

  static String _key(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}


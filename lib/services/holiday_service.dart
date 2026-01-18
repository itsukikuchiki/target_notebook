import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../core/app_config.dart';

class HolidayService {
  HolidayService._();
  static final HolidayService I = HolidayService._();

  /// region-year -> { "YYYY-MM-DD": "Holiday name" }
  final Map<String, Map<String, String>> _cache = {};

  Map<String, dynamic>? _manifest;

  AppRegion get _region => AppConfig.region;

  /// 预加载：用于月视图（避免 UI 每个格子都触发 IO）
  Future<void> prefetchYears(Iterable<int> years) async {
    final set = years.toSet();
    for (final y in set) {
      await _loadYear(region: _region, year: y);
    }
  }

  /// 获取某天的祝日名（不存在返回 null）
  Future<String?> nameOf(DateTime day) async {
    final map = await _loadYear(region: _region, year: day.year);
    return map[_key(day)];
  }

  /// 某天是否祝日
  Future<bool> isHoliday(DateTime day) async {
    final map = await _loadYear(region: _region, year: day.year);
    return map.containsKey(_key(day));
  }

  /// 清空缓存（调试用）
  void clearCache() {
    _cache.clear();
    _manifest = null;
  }

  // ---------------- internal ----------------

  String _regionFolder(AppRegion r) => r == AppRegion.tw ? 'tw' : 'jp';

  Future<Map<String, dynamic>> _loadManifest() async {
    if (_manifest != null) return _manifest!;
    final raw = await rootBundle.loadString('AssetManifest.json');
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      _manifest = decoded;
      return decoded;
    }
    _manifest = <String, dynamic>{};
    return _manifest!;
  }

  Future<Map<String, String>> _loadYear({
    required AppRegion region,
    required int year,
  }) async {
    final folder = _regionFolder(region);
    final cacheKey = '$folder-$year';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final path = 'assets/holidays/$folder/$year.json';

    // 不存在则直接返回空（不会抛异常）
    final manifest = await _loadManifest();
    if (!manifest.containsKey(path)) {
      final empty = <String, String>{};
      _cache[cacheKey] = empty;
      return empty;
    }

    try {
      final raw = await rootBundle.loadString(path);
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



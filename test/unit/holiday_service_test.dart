// test/unit/holiday_service_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:target_notebook/core/app_config.dart';
import 'package:target_notebook/services/holiday_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nameOf/isHoliday returns value when manifest contains year json', () async {
    final now = DateTime.now();
    final y = now.year;
    final key = _ymd(now);

    final yearPath = 'assets/holidays/jp/$y.json';

    final bundle = _FakeAssetBundle({
      // AssetManifest.json 必须存在
      'AssetManifest.json': jsonEncode({
        yearPath: [yearPath],
      }),
      // year json：写死今天为祝日
      yearPath: jsonEncode({
        key: 'Test Holiday',
      }),
    });

    final svc = HolidayService(region: AppRegion.jp, bundle: bundle);

    final name = await svc.nameOf(now);
    expect(name, 'Test Holiday');

    final yes = await svc.isHoliday(now);
    expect(yes, true);

    final no = await svc.isHoliday(now.add(const Duration(days: 1)));
    expect(no, false);
  });

  test('prefetchYears caches and avoids repeated asset reads', () async {
    final now = DateTime.now();
    final y = now.year;
    final key = _ymd(now);

    final yearPath = 'assets/holidays/jp/$y.json';

    int manifestReads = 0;
    int yearReads = 0;

    final bundle = _FakeAssetBundle(
      {
        'AssetManifest.json': jsonEncode({yearPath: [yearPath]}),
        yearPath: jsonEncode({key: 'Cached Holiday'}),
      },
      onLoad: (assetKey) {
        if (assetKey == 'AssetManifest.json') manifestReads++;
        if (assetKey == yearPath) yearReads++;
      },
    );

    final svc = HolidayService(region: AppRegion.jp, bundle: bundle);

    await svc.prefetchYears([y]);

    // 第一次查询：应命中缓存
    final name1 = await svc.nameOf(now);
    expect(name1, 'Cached Holiday');

    // 第二次查询：仍命中缓存
    final name2 = await svc.nameOf(now);
    expect(name2, 'Cached Holiday');

    // ✅ 断言：manifest 只读一次；year json 只读一次
    expect(manifestReads, 1);
    expect(yearReads, 1);
  });

  test('returns null/false when year asset not in manifest', () async {
    final now = DateTime.now();
    final y = now.year;

    final yearPath = 'assets/holidays/jp/$y.json';

    final bundle = _FakeAssetBundle({
      // manifest 不包含 yearPath
      'AssetManifest.json': jsonEncode({}),
      // 即使给了 year 文件内容，也不会被读（service 会先看 manifest）
      yearPath: jsonEncode({_ymd(now): 'SHOULD_NOT_LOAD'}),
    });

    final svc = HolidayService(region: AppRegion.jp, bundle: bundle);

    final name = await svc.nameOf(now);
    expect(name, isNull);

    final yes = await svc.isHoliday(now);
    expect(yes, false);
  });
}

/// -----------------------
/// helpers
/// -----------------------

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(
    this.assets, {
    this.onLoad,
  });

  final Map<String, String> assets;
  final void Function(String assetKey)? onLoad;

  @override
  Future<ByteData> load(String key) async {
    onLoad?.call(key);

    final value = assets[key];
    if (value == null) {
      throw FlutterError('Asset not found: $key');
    }
    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.view(bytes.buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    onLoad?.call(key);

    final value = assets[key];
    if (value == null) {
      throw FlutterError('Asset not found: $key');
    }
    return value;
  }

  @override
  void clear() {
    // no-op for tests
  }

  @override
  Future<ui.ImmutableBuffer> loadBuffer(String key) async {
    final data = await load(key);
    return ui.ImmutableBuffer.fromUint8List(data.buffer.asUint8List());
  }

  @override
  Future<T> loadStructuredBinaryData<T>(
    String key,
    FutureOr<T> Function(ByteData data) parser,
  ) async {
    final data = await load(key);
    return Future<T>.value(parser(data));
  }
}


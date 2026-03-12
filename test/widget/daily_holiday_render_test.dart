// test/widget/daily_holiday_render_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/app_config.dart';
import 'package:target_notebook/core/hive_init.dart';

import 'package:target_notebook/adapters/dailylog_adapter.dart';
import 'package:target_notebook/adapters/task_adapter.dart' as ui;
import 'package:target_notebook/adapters/goal_tree_adapter.dart';
import 'package:target_notebook/pages/daily_page.dart';

import 'package:target_notebook/providers/settings_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';
import 'package:target_notebook/providers/daily_log_provider.dart';

import 'package:target_notebook/models/task.dart' show Task;
import 'package:target_notebook/services/holiday_service.dart';

import '../helpers/hive_test_env.dart';
import '../fakes/fake_notification_local_service.dart';
import '../fakes/fake_settings_provider.dart';

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this._strings);
  final Map<String, String> _strings;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final v = _strings[key];
    if (v == null) throw FlutterError('Asset not found: $key');
    return v;
  }

  @override
  Future<ByteData> load(String key) async {
    final v = _strings[key];
    if (v == null) throw FlutterError('Asset not found: $key');
    final bytes = Uint8List.fromList(utf8.encode(v));
    return ByteData.view(bytes.buffer);
  }
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  setUp(() async {
    await clearHiveBoxes();
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  testWidgets('DailyPage shows holiday name in red when selected day is holiday',
      (tester) async {
    final today = DateTime.now();
    final todayKey = _ymd(today);

    final folder = 'jp';
    final year = today.year;
    final path = 'assets/holidays/$folder/$year.json';

    const holidayName = 'TEST-HOLIDAY';

    final bundle = _FakeAssetBundle({
      'AssetManifest.json': jsonEncode({path: [path]}),
      path: jsonEncode({todayKey: holidayName}),
    });

    final holidaySvc = HolidayService(region: AppRegion.jp, bundle: bundle);

    final SettingsProvider settings = FakeSettingsProvider(
      inited: true,
      seenOnboarding: true,
      weekStart: WeekStart.monday,
      soundId: SoundId.none,
    );

    final taskP = TaskProvider();
    await taskP.init(
      taskBox: Hive.box<Task>(AppBoxes.task),
      notification: FakeNotificationLocalService(),
    );

    final taskA = ui.TaskAdapter(taskP);

    final logP = DailyLogProvider();
    await logP.init();
    final dailyA = DailyLogAdapter(logP);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HolidayService>.value(value: holidaySvc),

          ChangeNotifierProvider<SettingsProvider>.value(value: settings),

          ChangeNotifierProvider<DailyLogAdapter>.value(value: dailyA),
          ChangeNotifierProvider<ui.TaskAdapter>.value(value: taskA),

          Provider<GoalTreeAdapter?>.value(value: null),

          // ✅ 关键修复：TaskProvider 是 ChangeNotifier，必须用 ChangeNotifierProvider
          ChangeNotifierProvider<TaskProvider?>.value(value: taskP),
        ],
        child: const TickerMode(
          enabled: false,
          child: MaterialApp(home: DailyPage()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final holidayFinder = find.byKey(const Key('daily.holiday.name'));
    expect(holidayFinder, findsOneWidget);

    final w = tester.widget<Text>(holidayFinder);
    expect(w.data, holidayName);
    expect(w.style?.color, Colors.red);
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:target_notebook/core/app_config.dart';
import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/pages/daily_page.dart';
import 'package:target_notebook/pages/editors/task_edit_page.dart';
import 'package:target_notebook/providers/settings_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';
import 'package:target_notebook/services/holiday_service.dart';
import 'package:target_notebook/services/notification_local_service.dart';
import 'package:target_notebook/adapters/task_adapter.dart' as ui;
import 'package:target_notebook/adapters/dailylog_adapter.dart';
import 'package:target_notebook/adapters/goal_tree_adapter.dart';

import '../test/helpers/hive_test_env.dart';
import '../test/fakes/fake_notification_local_service.dart';
import '../test/fakes/ui_adapters_fakes.dart';

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this._assets);
  final Map<String, String> _assets;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final v = _assets[key];
    if (v == null) throw FlutterError('Asset not found: $key');
    return v;
  }

  @override
  Future<ByteData> load(String key) async {
    final v = _assets[key];
    if (v == null) throw FlutterError('Asset not found: $key');
    final bytes = Uint8List.fromList(utf8.encode(v));
    return ByteData.view(bytes.buffer);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await clearHiveBoxes();
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  Future<void> _pumpDaily(
    WidgetTester tester, {
    required TaskProvider taskP,
    required ui.TaskAdapter taskAdapter,
    required DailyLogAdapter daily,
    required SettingsProvider settings,
    required HolidayService holiday,
    required NotificationLocalService notif,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HolidayService>.value(value: holiday),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<DailyLogAdapter>.value(value: daily),
          ChangeNotifierProvider<ui.TaskAdapter>.value(value: taskAdapter),

          // DailyPage week strip 取点颜色：用 nullable provider
          ChangeNotifierProvider<TaskProvider?>.value(value: taskP),
          Provider<GoalTreeAdapter?>.value(value: null),

          Provider<NotificationLocalService>.value(value: notif),
        ],
        child: MaterialApp(
          routes: {
            TaskEditPage.route: (_) => const TaskEditPage(),
          },
          home: const DailyPage(),
        ),
      ),
    );

    await tester.pump(); // first frame
    await tester.pumpAndSettle(const Duration(seconds: 2)); // wait async holiday refresh
  }

  testWidgets('guest daily smoke: add -> open detail -> mark done -> save -> reboot persists', (tester) async {
    final notif = FakeNotificationLocalService();

    final taskP = TaskProvider();
    await taskP.init(
      taskBox: Hive.box<Task>(AppBoxes.task),
      notification: notif,
    );
    final taskAdapter = ui.TaskAdapter(taskP);

    final daily = FakeDailyLogAdapter();

    final settings = SettingsProvider();
    await settings.init();

    // holiday service: empty manifest => always no holiday (but should not crash)
    final bundle = _FakeAssetBundle({
      'AssetManifest.json': jsonEncode(<String, dynamic>{}),
    });
    final holiday = HolidayService(region: AppRegion.jp, bundle: bundle);

    await _pumpDaily(
      tester,
      taskP: taskP,
      taskAdapter: taskAdapter,
      daily: daily,
      settings: settings,
      holiday: holiday,
      notif: notif,
    );

    // 1) add task via FAB dialog
    await tester.tap(find.byKey(const Key('daily.addTask.fab')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('daily.addTask.title')), 'SMOKE-1');
    await tester.tap(find.byKey(const Key('daily.addTask.save')));
    await tester.pumpAndSettle();

    // 2) task appears
    expect(find.text('SMOKE-1'), findsOneWidget);

    // 3) open detail by tapping tile (find the ListTile with that text)
    await tester.tap(find.widgetWithText(ListTile, 'SMOKE-1'));
    await tester.pumpAndSettle();

    // 4) mark done (TaskEditPage: 第 0 个 switch 是 alarm，第 1 个是 done)
    final switches = find.byType(Switch);
    expect(switches, findsWidgets);

    // done switch is usually the 2nd one
    await tester.tap(switches.at(1));
    await tester.pumpAndSettle();

    // 5) save
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 6) back to DailyPage: done icon should appear for the task
    // trailing icon uses check_circle when done
    expect(find.byIcon(Icons.check_circle), findsWidgets);

    // 7) reboot simulation: rebuild providers from Hive
    final taskP2 = TaskProvider();
    await taskP2.init(
      taskBox: Hive.box<Task>(AppBoxes.task),
      notification: notif,
    );
    final taskAdapter2 = ui.TaskAdapter(taskP2);

    await _pumpDaily(
      tester,
      taskP: taskP2,
      taskAdapter: taskAdapter2,
      daily: daily,
      settings: settings,
      holiday: holiday,
      notif: notif,
    );

    // task still exists
    expect(find.text('SMOKE-1'), findsOneWidget);

    // and still done
    expect(find.byIcon(Icons.check_circle), findsWidgets);
  });
}

// test/widget/daily_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/core/app_config.dart';

import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/pages/daily_page.dart';
import 'package:target_notebook/providers/task_provider.dart';
import 'package:target_notebook/providers/settings_provider.dart';
import 'package:target_notebook/services/holiday_service.dart';

import 'package:target_notebook/adapters/task_adapter.dart' as ui;
import 'package:target_notebook/adapters/dailylog_adapter.dart';
import 'package:target_notebook/adapters/goal_tree_adapter.dart';

import '../helpers/hive_test_env.dart';
import '../fakes/fake_notification_local_service.dart';
import '../fakes/ui_adapters_fakes.dart';

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _pumpFor(
  WidgetTester tester,
  Duration total, {
  Duration step = const Duration(milliseconds: 20),
}) async {
  final steps = (total.inMilliseconds / step.inMilliseconds)
      .ceil()
      .clamp(1, 1 << 30);
  for (int i = 0; i < steps; i++) {
    await tester.pump(step);
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxSteps = 300,
  Duration step = const Duration(milliseconds: 20),
}) async {
  for (int i = 0; i < maxSteps; i++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timeout waiting for ${finder.description}');
}

class _DailyHarness {
  final Widget app;
  final TaskProvider taskP;
  final ui.TaskAdapter taskAdapter;
  final FakeDailyLogAdapter dailyLog;
  final _TestSettingsProvider settingsP;

  _DailyHarness({
    required this.app,
    required this.taskP,
    required this.taskAdapter,
    required this.dailyLog,
    required this.settingsP,
  });

  void dispose() {
    taskAdapter.dispose();
    taskP.dispose();
    dailyLog.dispose();
    settingsP.dispose();
  }
}

Future<_DailyHarness> _buildHarness() async {
  final holidaySvc = _FakeHolidayService(const {});
  final notif = FakeNotificationLocalService();

  final taskP = TaskProvider();
  await taskP.init(
    taskBox: Hive.box<Task>(AppBoxes.task),
    notification: notif,
  );

  final taskAdapter = ui.TaskAdapter(taskP);
  final fakeDaily = FakeDailyLogAdapter();

  // ✅ 关键：DailyPage 会 read/watch SettingsProvider（weekStart）
  final settingsP = _TestSettingsProvider(weekStart: WeekStart.monday);

  final app = MultiProvider(
    providers: [
      Provider<HolidayService>.value(value: holidaySvc),

      // DailyPage build() 中 watch 的
      ChangeNotifierProvider<DailyLogAdapter>.value(value: fakeDaily),
      ChangeNotifierProvider<ui.TaskAdapter>.value(value: taskAdapter),
      ChangeNotifierProvider<SettingsProvider>.value(value: settingsP),

      // WeekStrip 中 Provider.of 读取的（nullable）
      ChangeNotifierProvider<TaskProvider?>.value(value: taskP),
      Provider<GoalTreeAdapter?>.value(value: null),
    ],
    child: const MaterialApp(home: DailyPage()),
  );

  return _DailyHarness(
    app: app,
    taskP: taskP,
    taskAdapter: taskAdapter,
    dailyLog: fakeDaily,
    settingsP: settingsP,
  );
}

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

  testWidgets('DailyPage: week/month toggle switches calendar UI', (tester) async {
    final harness = await _buildHarness();

    addTearDown(() async {
      harness.dispose();
      await _unmount(tester);
    });

    await tester.pumpWidget(harness.app);
    await _pumpFor(tester, const Duration(milliseconds: 300));

    // 默认 week：不应出现 CalendarDatePicker
    expect(find.byType(CalendarDatePicker), findsNothing);

    // 切换到 month
    await tester.tap(find.byKey(const Key('daily.view.month')));
    await _pumpFor(tester, const Duration(milliseconds: 250));
    expect(find.byType(CalendarDatePicker), findsOneWidget);

    // 切回 week
    await tester.tap(find.byKey(const Key('daily.view.week')));
    await _pumpFor(tester, const Duration(milliseconds: 250));
    expect(find.byType(CalendarDatePicker), findsNothing);
  });

  testWidgets('DailyPage: quick add task shows in list and persists to Hive', (tester) async {
    final harness = await _buildHarness();

    addTearDown(() async {
      harness.dispose();
      await _unmount(tester);
    });

    await tester.pumpWidget(harness.app);
    await _pumpFor(tester, const Duration(milliseconds: 300));

    // 点 FAB
    final fab = find.byKey(const Key('daily.addTask.fab'));
    await _pumpUntilFound(tester, fab);
    await tester.tap(fab);
    await _pumpFor(tester, const Duration(milliseconds: 250));

    // 输入标题
    final titleField = find.byKey(const Key('daily.addTask.title'));
    await _pumpUntilFound(tester, titleField);
    await tester.enterText(titleField, 'My Task 1');
    await _pumpFor(tester, const Duration(milliseconds: 80));

    // 保存
    final saveBtn = find.byKey(const Key('daily.addTask.save'));
    await _pumpUntilFound(tester, saveBtn);
    await tester.tap(saveBtn);
    await _pumpFor(tester, const Duration(milliseconds: 400));

    // 页面出现任务 title
    await _pumpUntilFound(tester, find.text('My Task 1'));
    expect(find.text('My Task 1'), findsOneWidget);

    // Hive 里也应有 Task
    final box = Hive.box<Task>(AppBoxes.task);
    expect(box.values.any((t) => t.title == 'My Task 1'), isTrue);
  });
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class _FakeHolidayService extends HolidayService {
  final Map<String, String> byDay;

  _FakeHolidayService(this.byDay) : super(region: AppRegion.jp);

  @override
  Future<void> prefetchYears(Iterable<int> years) async {}

  @override
  Future<String?> nameOf(DateTime day) async {
    final k = _ymd(DateTime(day.year, day.month, day.day));
    return byDay[k];
  }

  @override
  Future<bool> isHoliday(DateTime day) async => (await nameOf(day)) != null;

  @override
  void clearCache() {}
}

/// ✅ 最小可用的 SettingsProvider：只保证 weekStart 可读 + 能被 watch
/// 如果 SettingsProvider 接口后续新增成员，这里用 noSuchMethod 吃掉，避免测试编译炸。
class _TestSettingsProvider extends ChangeNotifier implements SettingsProvider {
  _TestSettingsProvider({required WeekStart weekStart}) : _weekStart = weekStart;

  WeekStart _weekStart;

  @override
  WeekStart get weekStart => _weekStart;

  // 方便你未来写“切换周起始日”的测试
  void setWeekStartForTest(WeekStart v) {
    _weekStart = v;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

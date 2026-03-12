// integration_test/mvp_schedule_calendar_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/providers/task_provider.dart';
import 'package:target_notebook/adapters/task_adapter.dart';
import 'package:target_notebook/adapters/goal_tree_adapter.dart';
import 'package:target_notebook/pages/daily_page.dart';
import 'package:target_notebook/pages/editors/task_edit_page.dart';

import '../test/helpers/hive_test_env.dart';
import '../test/fakes/fake_notification_local_service.dart';
import '../test/fakes/ui_adapters_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  setUp(() async {
    await clearHiveBoxes();
    try {
      if (Hive.isBoxOpen('settings')) {
        await Hive.box('settings').clear();
      }
    } catch (_) {}
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  testWidgets(
    'MVP Daily: month/week -> add -> edit fields (note/location/participants/allDay/priority/completion/done/alarm) -> save -> schedule -> reboot persists',
    (tester) async {
      final notif = FakeNotificationLocalService();

      // 1) 首次启动
      await _pumpDailyHarness(tester, notif: notif);

      // 2) 月/周切换
      await tester.tap(find.byKey(const Key('daily.view.month')));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDatePicker), findsOneWidget);

      await tester.tap(find.byKey(const Key('daily.view.week')));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDatePicker), findsNothing);

      // 3) 新增任务（title）
      await tester.tap(find.byKey(const Key('daily.addTask.fab')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('daily.addTask.title')), 'CAL-1');
      await tester.tap(find.byKey(const Key('daily.addTask.save')));
      await tester.pumpAndSettle();

      expect(find.text('CAL-1'), findsOneWidget);

      // 取 taskKey（Hive key）
      final taskBox = Hive.box<Task>(AppBoxes.task);
      final int taskKey = taskBox.keys.cast<int>().firstWhere(
            (k) => taskBox.get(k)!.title == 'CAL-1',
          );

      // 4) 进编辑页
      await tester.tap(find.byKey(Key('daily.task.item.$taskKey')));
      await tester.pumpAndSettle();
      expect(find.text('编辑日程/任务'), findsOneWidget);

      // 5) 填字段（不走 date/time picker）
      await _enterTextByLabel(tester, label: '备忘录（可选）', text: 'note-1');
      await _enterTextByLabel(tester, label: '地点（可选）', text: 'Ginza');
      // participants：含重复/换行/分号，让 normalize 生效
      await _enterTextByLabel(
        tester,
        label: '参与者邮箱（可选）',
        text: 'A@A.com\nb@b.com; a@a.com',
      );

      // alarm on（row 里第一个 switch）
      await _setSwitchInRowByText(tester, rowText: '提醒（alarm）', value: true);

      // done on（“已完成/未完成”这行的 switch）
      await _setSwitchNearText(tester, nearText: '未完成', value: true);

      // priority: Dropdown -> 选 P1
      await _selectPriority(tester, priority: 1);

      // all day on
      await _setSwitchNearText(tester, nearText: '全日', value: true);

      // completion slider：done=true 会锁 100%，这里顺手断言显示 100%
      expect(find.text('100%'), findsWidgets);

      // 保存
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 6) schedule 被调用（至少 1 次）
      expect(notif.scheduleCalls.isNotEmpty, true);
      // 只要有一次 title 为 CAL-1 即可（provider 可能幂等重复 schedule）
      expect(notif.scheduleCalls.any((c) => c.title == 'CAL-1'), true);

      // 7) 回到列表页：subtitle 应出现 全日/地点/人数/P/百分比（来自 DailyPage _buildTaskSubtitle）
      // ListTile subtitle 是 Text，contains 即可
      expect(find.textContaining('全日'), findsWidgets);
      expect(find.textContaining('Ginza'), findsWidgets);
      expect(find.textContaining('2人'), findsWidgets);
      expect(find.textContaining('P1'), findsWidgets);
      expect(find.textContaining('100%'), findsWidgets);

      // 8) 重启模拟（providers 重建，Hive 不清）
      await _pumpDailyHarness(tester, notif: notif, reboot: true);

      // 任务仍在
      expect(find.text('CAL-1'), findsOneWidget);

      // 9) 再进编辑页，逐项确认持久化字段
      await tester.tap(find.byKey(Key('daily.task.item.$taskKey')));
      await tester.pumpAndSettle();

      // 标题
      expect(find.text('编辑日程/任务'), findsOneWidget);

      // note
      expect(_textFieldHasText(label: '备忘录（可选）', text: 'note-1', tester: tester), true);

      // location
      expect(_textFieldHasText(label: '地点（可选）', text: 'Ginza', tester: tester), true);

      // participants normalize 后应为 "A@A.com, b@b.com" 或大小写稍不同（保存里会 lower 去重但保留原 p）
      // 这里宽松：只要包含 a@a.com 和 b@b.com（不区分大小写）
      final pText = _getTextFieldTextByLabel(tester, '参与者邮箱（可选）').toLowerCase();
      expect(pText.contains('a@a.com'), true);
      expect(pText.contains('b@b.com'), true);

      // alarm switch still on
      expect(_switchValueInRowByText(tester, rowText: '提醒（alarm）'), true);

      // all day still on
      expect(_switchValueNearText(tester, nearText: '全日'), true);

      // done still on
      expect(_switchValueNearText(tester, nearText: '已完成'), true);

      // priority shows P1 somewhere on page (row shows P$_priority)
      expect(find.text('P1'), findsWidgets);
    },
  );
}

Future<void> _pumpDailyHarness(
  WidgetTester tester, {
  required FakeNotificationLocalService notif,
  bool reboot = false,
}) async {
  final taskP = TaskProvider();
  await taskP.init(taskBox: Hive.box<Task>(AppBoxes.task), notification: notif);

  final taskAdapter = TaskAdapter(taskP);
  final fakeDaily = FakeDailyLogAdapter();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<GoalTreeAdapter?>.value(value: null),
        Provider<TaskProvider?>.value(value: taskP),
        ChangeNotifierProvider.value(value: taskAdapter),
        ChangeNotifierProvider.value(value: fakeDaily),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        routes: {
          TaskEditPage.route: (_) => const TaskEditPage(),
        },
        home: Scaffold(
          appBar: AppBar(title: Text(reboot ? 'Daily(Reboot)' : 'Daily')),
          body: const DailyPage(),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

// ----------------------- helpers -----------------------

Finder _textFormFieldByLabel(String label) {
  return find.byWidgetPredicate((w) {
    if (w is! TextFormField) return false;
    final d = w.decoration;
    return d?.labelText == label;
  });
}

Future<void> _enterTextByLabel(
  WidgetTester tester, {
  required String label,
  required String text,
}) async {
  final f = _textFormFieldByLabel(label);
  expect(f, findsOneWidget);
  await tester.enterText(f, text);
  await tester.pumpAndSettle();
}

String _getTextFieldTextByLabel(WidgetTester tester, String label) {
  final f = _textFormFieldByLabel(label);
  final tf = tester.widget<TextFormField>(f);
  return tf.controller?.text ?? '';
}

bool _textFieldHasText({
  required WidgetTester tester,
  required String label,
  required String text,
}) {
  final actual = _getTextFieldTextByLabel(tester, label);
  return actual == text;
}

Future<void> _setSwitchInRowByText(
  WidgetTester tester, {
  required String rowText,
  required bool value,
}) async {
  final row = find.ancestor(of: find.text(rowText), matching: find.byType(Row));
  expect(row, findsWidgets);

  final sw = find.descendant(of: row.first, matching: find.byType(Switch));
  expect(sw, findsOneWidget);

  final Switch s = tester.widget(sw);
  if (s.value == value) return;

  await tester.tap(sw);
  await tester.pumpAndSettle();
}

bool _switchValueInRowByText(
  WidgetTester tester, {
  required String rowText,
}) {
  final row = find.ancestor(of: find.text(rowText), matching: find.byType(Row));
  final sw = find.descendant(of: row.first, matching: find.byType(Switch));
  final Switch s = tester.widget(sw);
  return s.value;
}

Future<void> _setSwitchNearText(
  WidgetTester tester, {
  required String nearText,
  required bool value,
}) async {
  final anchor = find.text(nearText);
  expect(anchor, findsWidgets);

  final row = find.ancestor(of: anchor.first, matching: find.byType(Row));
  expect(row, findsWidgets);

  final sw = find.descendant(of: row.first, matching: find.byType(Switch));
  expect(sw, findsOneWidget);

  final Switch s = tester.widget(sw);
  if (s.value == value) return;

  await tester.tap(sw);
  await tester.pumpAndSettle();
}

bool _switchValueNearText(
  WidgetTester tester, {
  required String nearText,
}) {
  final anchor = find.text(nearText);
  final row = find.ancestor(of: anchor.first, matching: find.byType(Row));
  final sw = find.descendant(of: row.first, matching: find.byType(Switch));
  final Switch s = tester.widget(sw);
  return s.value;
}

Future<void> _selectPriority(
  WidgetTester tester, {
  required int priority,
}) async {
  final dd = find.byType(DropdownButton<int>);
  expect(dd, findsOneWidget);

  await tester.tap(dd);
  await tester.pumpAndSettle();

  // DropdownMenuItem 文案是 'P$v'
  await tester.tap(find.text('P$priority').last);
  await tester.pumpAndSettle();
}

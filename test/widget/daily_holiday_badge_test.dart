// test/widget/daily_holiday_badge_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import 'package:target_notebook/core/app_config.dart';
import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/pages/daily_page.dart';
import 'package:target_notebook/providers/settings_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';
import 'package:target_notebook/services/holiday_service.dart';
import 'package:target_notebook/adapters/task_adapter.dart' as ui;
import 'package:target_notebook/adapters/dailylog_adapter.dart';
import 'package:target_notebook/adapters/goal_tree_adapter.dart';

import '../helpers/hive_test_env.dart';
import '../fakes/fake_notification_local_service.dart';
import '../fakes/ui_adapters_fakes.dart';
import '../fakes/fake_settings_provider.dart';

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

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

Future<void> _pumpAWhile(WidgetTester tester, [int ms = 300]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
  await tester.pump(Duration(milliseconds: ms));
}

String? _plainTextOfRichText(RichText rt) {
  final ts = rt.text;
  if (ts is TextSpan) return ts.toPlainText();
  return null;
}

Color? _firstColorInTextSpan(InlineSpan span) {
  if (span is TextSpan) {
    final c = span.style?.color;
    if (c != null) return c;
    final children = span.children;
    if (children != null) {
      for (final ch in children) {
        final cc = _firstColorInTextSpan(ch);
        if (cc != null) return cc;
      }
    }
  }
  return null;
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

  testWidgets('DailyPage shows holiday name and red day number in week strip',
      (tester) async {
    final today = DateTime.now();
    const holidayName = 'UnitTest Holiday';

    final yearPath = 'assets/holidays/jp/${today.year}.json';
    final bundle = _FakeAssetBundle({
      'AssetManifest.json': jsonEncode({yearPath: [yearPath]}),
      yearPath: jsonEncode({_ymd(today): holidayName}),
    });
    final holidaySvc = HolidayService(region: AppRegion.jp, bundle: bundle);

    final taskP = TaskProvider();
    await taskP.init(
      taskBox: Hive.box<Task>(AppBoxes.task),
      notification: FakeNotificationLocalService(),
    );
    final taskAdapter = ui.TaskAdapter(taskP);

    final fakeDaily = FakeDailyLogAdapter();

    final SettingsProvider settings = FakeSettingsProvider(
      inited: true,
      seenOnboarding: true,
      weekStart: WeekStart.monday,
      soundId: SoundId.none,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HolidayService>.value(value: holidaySvc),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),

          ChangeNotifierProvider<DailyLogAdapter>.value(value: fakeDaily),
          ChangeNotifierProvider<ui.TaskAdapter>.value(value: taskAdapter),

          ChangeNotifierProvider<TaskProvider?>.value(value: taskP),
          Provider<GoalTreeAdapter?>.value(value: null),
        ],
        child: const MaterialApp(home: DailyPage()),
      ),
    );

    await _pumpAWhile(tester);

    // 1) 先确认 holiday 名出现（这是你页面已经支持的稳定断言）
    expect(find.text(holidayName), findsOneWidget);

    // 2) 再找 week strip 上“今天的日号”，但不假设它一定是 Text widget
    final dayStr = '${today.day}';
    final errorColor =
        Theme.of(tester.element(find.byType(DailyPage))).colorScheme.error;

    // 2.1 先尝试 Text 中包含 dayStr 的候选
    final textCandidates = find.byWidgetPredicate((w) {
      return w is Text && (w.data == dayStr);
    });

    // 2.2 再尝试 RichText 中包含 dayStr 的候选（很多 UI 会用 Text.rich）
    final richCandidates = find.byType(RichText).evaluate().where((e) {
      final rt = e.widget as RichText;
      final plain = _plainTextOfRichText(rt);
      return plain != null && plain.trim() == dayStr;
    }).toList();

    bool hasRed = false;

    // 先检查 Text（含 inherited style 合并）
    for (final e in textCandidates.evaluate()) {
      final t = e.widget as Text;
      final inherited = DefaultTextStyle.of(e).style;
      final merged = inherited.merge(t.style);
      final c = merged.color;
      if (c == Colors.red || c == errorColor) {
        hasRed = true;
        break;
      }
    }

    // 再检查 RichText（从 span style 找 color；如果没有就用 DefaultTextStyle）
    if (!hasRed) {
      for (final e in richCandidates) {
        final rt = e.widget as RichText;

        final spanColor = _firstColorInTextSpan(rt.text);
        final inherited = DefaultTextStyle.of(e).style.color;

        final c = spanColor ?? inherited;
        if (c == Colors.red || c == errorColor) {
          hasRed = true;
          break;
        }
      }
    }

    // 说明连“日号 widget”都没找到：把错误信息做得可读一点
    final foundAnyDayWidget =
        textCandidates.evaluate().isNotEmpty || richCandidates.isNotEmpty;
    expect(foundAnyDayWidget, true,
        reason:
            'Could not find a day-number widget equal to "$dayStr" in week strip. '
            'If week strip uses a custom widget, please add a Key for today cell.');

    expect(hasRed, true,
        reason:
            'Found day-number "$dayStr" widget but its effective color is not red/errorColor.');
  });
}

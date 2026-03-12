import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:target_notebook/core/result.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/pages/editors/task_edit_page.dart';
import 'package:target_notebook/providers/task_provider.dart';

class _FakeTaskProvider extends TaskProvider {
  Task? lastAdded;

  @override
  Future<void> init({dynamic taskBox, String boxName = '', dynamic notification}) async {
    // no-op (avoid Hive)
  }

  @override
  Future<Result<int>> addTask(Task t) async {
    lastAdded = t;
    return const Success(0);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TaskEditPage: alarm enabled with past default -> save falls back to now+1h',
    (tester) async {
      final taskP = _FakeTaskProvider();

      final now0 = DateTime.now();
      final yesterday = DateTime(now0.year, now0.month, now0.day)
          .subtract(const Duration(days: 1));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TaskProvider>.value(value: taskP),
          ],
          child: MaterialApp(
            initialRoute: TaskEditPage.route,
            onGenerateRoute: (settings) {
              if (settings.name == TaskEditPage.route) {
                // ✅ create flow: 传 Map，startAt 会被设为“昨天 09:00”
                return MaterialPageRoute(
                  settings: RouteSettings(
                    name: TaskEditPage.route,
                    arguments: <String, dynamic>{
                      'date': yesterday,
                      'goalId': null,
                      'subGoalId': null,
                    },
                  ),
                  builder: (_) => const TaskEditPage(),
                );
              }
              return null;
            },
          ),
        ),
      );

      // 不用 pumpAndSettle：固定 pump 几次即可
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 打开 alarm（默认 alarmAt=null，会走 startAt-10min；但 startAt=昨天 => past => fallback now+1h）
      final switches = find.byType(Switch);
      expect(switches, findsWidgets);
      await tester.tap(switches.at(0));
      await tester.pump(const Duration(milliseconds: 200));

      final beforeSave = DateTime.now();

      await tester.tap(find.text('保存'));
      await tester.pump(const Duration(milliseconds: 200));

      final saved = taskP.lastAdded;
      expect(saved, isNotNull);

      expect(saved!.hasAlarm, true);
      expect(saved.alarmAt, isNotNull);

      // 兜底应在未来（>= now+50min 容错）
      final minExpected = beforeSave.add(const Duration(minutes: 50));
      expect(
        saved.alarmAt!.isAfter(minExpected) ||
            saved.alarmAt!.isAtSameMomentAs(minExpected),
        true,
      );
    },
  );
}

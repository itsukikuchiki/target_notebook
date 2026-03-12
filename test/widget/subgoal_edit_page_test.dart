// test/widget/subgoal_edit_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/sub_goal.dart';
import 'package:target_notebook/providers/sub_goal_provider.dart';
import 'package:target_notebook/pages/editors/subgoal_edit_page.dart';

import '../helpers/hive_test_env.dart';

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Future<void> _pumpFor(
  WidgetTester tester,
  Duration total, {
  Duration step = const Duration(milliseconds: 20),
}) async {
  final steps = (total.inMilliseconds / step.inMilliseconds).ceil().clamp(1, 1 << 30);
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

void main() {
  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  setUp(() async {
    await clearHiveBoxes();
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  testWidgets('SubGoalEditPage shows hint when missing args', (tester) async {
    final subP = SubGoalProvider();
    await subP.init(box: Hive.box<SubGoal>(AppBoxes.subGoal));

    addTearDown(() async {
      subP.dispose();
      await _unmount(tester);
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: subP,
        child: const MaterialApp(home: SubGoalEditPage()),
      ),
    );

    await _pumpFor(tester, const Duration(milliseconds: 250));
    await _pumpUntilFound(tester, find.textContaining('缺少路由参数'));
    expect(find.textContaining('缺少路由参数'), findsOneWidget);
  });

  testWidgets('SubGoalEditPage saves new subgoal with args', (tester) async {
    final subP = SubGoalProvider();
    await subP.init(box: Hive.box<SubGoal>(AppBoxes.subGoal));

    addTearDown(() async {
      subP.dispose();
      await _unmount(tester);
    });

    const routeName = '/edit-subgoal';

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: subP,
        child: MaterialApp(
          initialRoute: routeName,
          onGenerateRoute: (settings) {
            if (settings.name != routeName) return null;
            return MaterialPageRoute(
              settings: const RouteSettings(
                name: routeName,
                arguments: SubGoalEditArgs(goalId: 10),
              ),
              builder: (_) => const SubGoalEditPage(),
            );
          },
        ),
      ),
    );

    await _pumpFor(tester, const Duration(milliseconds: 300));

    // title required
    final save = find.text('保存');
    await _pumpUntilFound(tester, save);
    expect(save, findsOneWidget);

    await tester.tap(save);
    await _pumpFor(tester, const Duration(milliseconds: 250));
    expect(find.text('请输入标题'), findsOneWidget);

    final field = find.byType(TextFormField).first;
    await _pumpUntilFound(tester, field);
    await tester.enterText(field, 'SG-UI');
    await _pumpFor(tester, const Duration(milliseconds: 80));

    await tester.tap(save);
    await _pumpFor(tester, const Duration(milliseconds: 350));

    final box = Hive.box<SubGoal>(AppBoxes.subGoal);
    expect(box.isNotEmpty, isTrue);
    final s = box.values.first;
    expect(s.goalId, 10);
    expect(s.title, 'SG-UI');
  });
}

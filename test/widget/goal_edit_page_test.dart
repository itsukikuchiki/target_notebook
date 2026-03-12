import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/providers/goal_provider.dart';
import 'package:target_notebook/pages/editors/goal_edit_page.dart';

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

  testWidgets('GoalEditPage validates title and saves new goal', (tester) async {
    final goalP = GoalProvider();
    await goalP.init(
      goalBox: Hive.box<Goal>(AppBoxes.goal),
      logBox: Hive.box(AppBoxes.dailyLog),
    );

    addTearDown(() async {
      goalP.dispose();
      await _unmount(tester);
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: goalP,
        child: const MaterialApp(home: GoalEditPage()),
      ),
    );

    await _pumpFor(tester, const Duration(milliseconds: 250));

    // empty -> error
    final save = find.text('保存');
    await _pumpUntilFound(tester, save);
    await tester.tap(save);
    await _pumpFor(tester, const Duration(milliseconds: 250));

    expect(find.text('请输入目标名称'), findsOneWidget);

    // input and save
    final field = find.byType(TextFormField).first;
    await _pumpUntilFound(tester, field);
    await tester.enterText(field, 'G-UI');
    await _pumpFor(tester, const Duration(milliseconds: 80));

    await tester.tap(save);
    await _pumpFor(tester, const Duration(milliseconds: 350));

    final box = Hive.box<Goal>(AppBoxes.goal);
    expect(box.isNotEmpty, isTrue);
    expect(box.values.first.title, 'G-UI');
  });
}

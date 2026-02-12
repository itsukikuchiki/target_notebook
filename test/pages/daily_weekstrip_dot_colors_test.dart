import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../fakes/fake_models.dart';
import '../fakes/fake_providers.dart';

class DotRuleWidget extends StatelessWidget {
  final DateTime selected;
  const DotRuleWidget({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    final goalP = context.watch<FakeGoalProvider>();
    final taskP = context.watch<FakeTaskProvider>();

    // 模拟 GoalTreeAdapter 给的 goalColorById
    final goals = goalP.goalsSorted;
    final goalColorById = <int, Color>{
      for (final g in goals) g.key: Color(goalP.effectiveColorInt(g, goalKey: g.key)),
    };

    List<Color> dayDotColors(DateTime day) {
      final list = taskP.tasksForDate(day);
      if (list.isEmpty) return const [];
      final colors = <Color>[];

      for (final t in list) {
        final c = (t.color != null)
            ? Color(t.color!)
            : (t.goalId != null && goalColorById.containsKey(t.goalId))
                ? goalColorById[t.goalId]!
                : Colors.blue; // default

        if (!colors.any((x) => x.value == c.value)) colors.add(c);
        if (colors.length >= 3) break;
      }
      return colors;
    }

    final colors = dayDotColors(selected);

    return MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            for (final c in colors)
              Container(
                key: Key('dot.${c.value}'),
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('Dot color priority: Task.color > Goal.color > default, unique max 3', (tester) async {
    final goalP = FakeGoalProvider();
    final taskP = FakeTaskProvider();

    goalP.seedGoals([
      FakeGoal(key: 1, title: 'G1', color: 0xFFFF0000), // red
    ]);

    final day = DateTime(2026, 1, 28);

    taskP.seedTasks([
      // same day tasks
      FakeTask(key: 1, title: 't1', goalId: 1, startAt: day, color: 0xFF00FF00), // green (task color)
      FakeTask(key: 2, title: 't2', goalId: 1, startAt: day, color: null),       // should use goal red
      FakeTask(key: 3, title: 't3', goalId: null, startAt: day, color: null),    // default blue
      FakeTask(key: 4, title: 't4', goalId: 1, startAt: day, color: 0xFF00FF00), // green duplicate -> removed
      FakeTask(key: 5, title: 't5', goalId: 1, startAt: day, color: 0xFFFFFF00), // yellow -> would be 4th but max 3
    ]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: goalP),
          ChangeNotifierProvider.value(value: taskP),
        ],
        child: DotRuleWidget(selected: day),
      ),
    );
    await tester.pumpAndSettle();

    // green exists
    expect(find.byKey(const Key('dot.4278255360')), findsOneWidget); // 0xFF00FF00
    // red exists
    expect(find.byKey(const Key('dot.4294901760')), findsOneWidget); // 0xFFFF0000
    // default blue exists
    expect(find.byKey(Key('dot.${Colors.blue.value}')), findsOneWidget);

    // yellow should NOT exist (4th color excluded)
    expect(find.byKey(const Key('dot.4294967040')), findsNothing); // 0xFFFFFF00
  });
}


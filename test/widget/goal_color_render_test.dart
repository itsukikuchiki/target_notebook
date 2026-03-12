// test/widget/goal_color_render_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:target_notebook/adapters/goal_tree_adapter.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/pages/my_journey_page.dart';
import 'package:target_notebook/providers/goal_provider.dart';
import 'package:target_notebook/providers/sub_goal_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';

class _FakeGoalTreeAdapter extends ChangeNotifier implements GoalTreeAdapter {
  @override
  final GoalProvider goalP;
  @override
  final SubGoalProvider subGoalP;
  @override
  final TaskProvider taskP;

  List<GoalNode> _goals;
  _FakeGoalTreeAdapter({
    required List<GoalNode> goals,
    GoalProvider? goalP,
    SubGoalProvider? subGoalP,
    TaskProvider? taskP,
  })  : _goals = goals,
        goalP = goalP ?? GoalProvider(),
        subGoalP = subGoalP ?? SubGoalProvider(),
        taskP = taskP ?? TaskProvider();

  @override
  List<GoalNode> get goals => _goals;

  void setGoals(List<GoalNode> next) {
    _goals = next;
    notifyListeners();
  }

  // 让未实现的方法在测试里不炸
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

bool _matchesCircleColor(Decoration? decoration, Color expected) {
  // BoxDecoration(circle,color)
  if (decoration is BoxDecoration) {
    if (decoration.shape == BoxShape.circle && decoration.color != null) {
      return decoration.color!.value == expected.value;
    }
  }

  // ShapeDecoration(CircleBorder/OvalBorder,color)
  if (decoration is ShapeDecoration) {
    final shape = decoration.shape;
    final color = decoration.color;
    final isCircleShape = shape is CircleBorder || shape is OvalBorder;
    if (isCircleShape && color != null) {
      return color.value == expected.value;
    }
  }

  return false;
}

/// 在“所有包含 title 的 Card”中，找任意一个 Card 内存在颜色 marker 就算通过。
/// 这样就不会误选到周焦点/重复文本的那张 Card。
void _expectAnyCardWithTitleHasColorMarker(
  WidgetTester tester, {
  required String title,
  required Color expected,
}) {
  final titleFinder = find.text(title);
  expect(titleFinder, findsWidgets, reason: 'Cannot find any Text("$title") in MyJourneyPage');

  final cardFinder = find.ancestor(of: titleFinder, matching: find.byType(Card));
  expect(cardFinder, findsWidgets, reason: 'Cannot find any Card ancestor for title="$title"');

  bool cardHasMarker(Finder card) {
    final markerFinder = find.descendant(
      of: card,
      matching: find.byWidgetPredicate((w) {
        // Container/DecoratedBox using Decoration
        if (w is Container) return _matchesCircleColor(w.decoration, expected);
        if (w is DecoratedBox) return _matchesCircleColor(w.decoration, expected);

        // CircleAvatar(backgroundColor)
        if (w is CircleAvatar) {
          final c = w.backgroundColor;
          return c != null && c.value == expected.value;
        }

        // Icon(color) 兜底
        if (w is Icon) {
          final c = w.color;
          return c != null && c.value == expected.value;
        }

        return false;
      }),
    );

    return tester.any(markerFinder);
  }

  final candidates = cardFinder.evaluate().map((e) => find.byWidget(e.widget)).toList();

  // 上面那行构造 Finder 不靠谱（同 widget 可能多处复用），更稳：按 index 一个个取
  // 所以改用：find.byType(Card).at(i) 来遍历“页面上的所有 Card”，然后筛选其中包含 title 的
  final allCards = find.byType(Card);
  final allCardsCount = allCards.evaluate().length;

  bool found = false;

  for (var i = 0; i < allCardsCount; i++) {
    final card = allCards.at(i);

    // 必须同时包含 title 文本
    final containsTitle = find.descendant(of: card, matching: find.text(title));
    if (!tester.any(containsTitle)) continue;

    if (cardHasMarker(card)) {
      found = true;
      break;
    }
  }

  expect(
    found,
    isTrue,
    reason:
        'Cannot find goal color marker (decoration/shapeDecoration/circleAvatar/icon) with color=${expected.value.toRadixString(16)} in ANY card containing title="$title".',
  );
}

void main() {
  testWidgets('MyJourneyPage renders goal color dot & weekly focus avatar color', (tester) async {
    // Arrange: 2 goals with fixed colors
    final g1 = Goal(title: 'G-Red', priority: 1, color: 0xFFFF0000);
    final g2 = Goal(title: 'G-Blue', priority: 2, color: 0xFF0000FF);

    final goals = <GoalNode>[
      GoalNode(
        goalKey: 1,
        goal: g1,
        color: const Color(0xFFFF0000),
        subGoals: const [],
        directTasks: const [],
        totalTasks: 0,
        doneTasks: 0,
      ),
      GoalNode(
        goalKey: 2,
        goal: g2,
        color: const Color(0xFF0000FF),
        subGoals: const [],
        directTasks: const [],
        totalTasks: 0,
        doneTasks: 0,
      ),
    ];

    final tree = _FakeGoalTreeAdapter(goals: goals);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<GoalTreeAdapter>.value(value: tree),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MyJourneyPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Assert: any card containing title has correct colored marker
    _expectAnyCardWithTitleHasColorMarker(
      tester,
      title: 'G-Red',
      expected: const Color(0xFFFF0000),
    );
    _expectAnyCardWithTitleHasColorMarker(
      tester,
      title: 'G-Blue',
      expected: const Color(0xFF0000FF),
    );

    // Assert: weekly focus section uses CircleAvatar backgroundColor = color.withOpacity(0.15)
    final focusTitle = find.text('本周三目标');
    expect(focusTitle, findsOneWidget);

    final firstRank = find.text('1');
    expect(firstRank, findsWidgets);

    // 取第一个“1”的 CircleAvatar（通常就是周焦点第一项）
    final avatarFinder = find.ancestor(of: firstRank.first, matching: find.byType(CircleAvatar));
    expect(avatarFinder, findsOneWidget);

    final CircleAvatar a = tester.widget(avatarFinder);
    expect(a.backgroundColor, isNotNull);

    // first focus item should be priority P1 => G-Red
    expect(a.backgroundColor!.value, const Color(0xFFFF0000).withOpacity(0.15).value);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeGoalNode {
  final String title;
  final int priority;
  final Color color;
  final int totalTasks;
  final int doneTasks;
  double get progress => totalTasks == 0 ? 0 : doneTasks / totalTasks;
  FakeGoalNode({
    required this.title,
    required this.priority,
    required this.color,
    required this.totalTasks,
    required this.doneTasks,
  });
}

class BurnCard extends StatelessWidget {
  final FakeGoalNode node;
  const BurnCard({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final total = node.totalTasks;
    final done = node.doneTasks;
    final remain = (total - done).clamp(0, 1 << 30);

    return MaterialApp(
      home: Scaffold(
        body: Card(
          child: Column(
            children: [
              Text(node.title),
              Text('P${node.priority}'),
              Text('Done $done / $total · Remaining $remain'),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('Burn card shows correct numbers', (tester) async {
    final node = FakeGoalNode(
      title: 'FP2',
      priority: 1,
      color: Colors.red,
      totalTasks: 10,
      doneTasks: 4,
    );

    await tester.pumpWidget(BurnCard(node: node));
    await tester.pumpAndSettle();

    expect(find.text('FP2'), findsOneWidget);
    expect(find.text('P1'), findsOneWidget);
    expect(find.text('Done 4 / 10 · Remaining 6'), findsOneWidget);
  });
}


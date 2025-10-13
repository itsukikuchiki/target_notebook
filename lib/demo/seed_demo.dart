import 'package:hive/hive.dart';
import '../core/hive_init.dart';
import '../models/goal.dart';
import '../models/kpi.dart';
import '../models/task.dart';

/// 仅用于 Week1 Demo：如果没有任何 Goal，则插入一套种子数据。
Future<void> ensureSeedData() async {
  final goalBox = Hive.box<Goal>(AppBoxes.goal);
  if (goalBox.isNotEmpty) return;

  final g1 = Goal(
    title: 'FP2 学习',
    description: '12 月通过日本 FP2 级',
    priority: 1,
    kpis: [
      KPI(name: '每周学习时长', targetValue: 10, currentValue: 0, unit: 'hrs', period: 'weekly'),
    ],
  );
  final g1Key = await goalBox.add(g1);

  final taskBox = Hive.box<Task>(AppBoxes.task);
  await taskBox.add(Task(
    goalId: g1Key,
    title: '本周完成官方题库 A1-A3',
    note: '每天 2 小时',
  ));
  await taskBox.add(Task(
    goalId: g1Key,
    title: '整理错题本',
  ));
}


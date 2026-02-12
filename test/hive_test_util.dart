import 'package:hive/hive.dart';

import 'helpers/hive_test_env.dart';
import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/sub_goal.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/models/daily_log.dart';

/// 兼容旧测试文件：不要再 Hive.init / Hive.close（会并发互踩）
/// 统一使用 test/helpers/hive_test_env.dart 的全局环境。
Future<void> setupHiveForTest() async {
  await ensureHiveReady();
}

/// 兼容旧测试文件：每个用例清空数据即可
Future<void> tearDownHiveForTest() async {
  await clearHiveBoxes();
}

/// 如果旧测试文件需要直接拿 box，这里也给个便捷方法（可选但常用）
Box<Goal> goalBox() => Hive.box<Goal>(AppBoxes.goal);
Box<SubGoal> subGoalBox() => Hive.box<SubGoal>(AppBoxes.subGoal);
Box<Task> taskBox() => Hive.box<Task>(AppBoxes.task);
Box<DailyLog> dailyLogBox() => Hive.box<DailyLog>(AppBoxes.dailyLog);


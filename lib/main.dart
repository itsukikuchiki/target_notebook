import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 1) Hive 初始化
import 'core/hive_init.dart';

// 2) Provider 层
import 'providers/nav_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/task_provider.dart';
import 'providers/daily_log_provider.dart';

// 3) UI Adapters（用于页面）
import 'adapters/goal_adapter.dart' as vm;
import 'adapters/task_adapter.dart' as vm;
import 'adapters/dailylog_adapter.dart' as vm;

// 4) 模型（仅为种子数据所需，起别名 m，避免与 UI Adapter 同名）
//    注意：这些文件里也声明了 Hive 的 *TypeAdapter*，名字也叫 GoalAdapter/TaskAdapter…
//    所以一定要用别名 `m.` 来引用模型类，避免与 vm. 冲突。
import 'models/goal.dart' as m;
import 'models/task.dart' as m;
import 'models/daily_log.dart' as m;

import 'app.dart';
import 'package:hive/hive.dart'; // 造数要用到 Hive.box

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 1) 初始化 Hive（注册适配器 + 打开所有 box）
  await initHive();

  // ✅ 2) 初始化各 Provider（绑定已打开的 box）
  final goalP = GoalProvider();
  final taskP = TaskProvider();
  final logP  = DailyLogProvider();
  await goalP.init();
  await taskP.init();
  await logP.init();

  // ✅ 3) （可选）种子数据：仅当三盒子都为空时造一份演示数据
  await _seedIfEmpty();

  // ✅ 4) 构造 UI 适配器（注意用 vm. 前缀）
  final nav    = NavProvider();
  final goalVM = vm.GoalAdapter(goalP, taskP);
  final taskVM = vm.TaskAdapter(taskP);
  final logVM  = vm.DailyLogAdapter(logP, taskP);

  // ✅ 5) 注入并启动
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: nav),
        ChangeNotifierProvider.value(value: goalP),
        ChangeNotifierProvider.value(value: taskP),
        ChangeNotifierProvider.value(value: logP),
        ChangeNotifierProvider.value(value: goalVM),
        ChangeNotifierProvider.value(value: taskVM),
        ChangeNotifierProvider.value(value: logVM),
      ],
      child: const TargetNotebookApp(),
    ),
  );
}

// ====== 仅本地演示用的种子数据：若三盒子为空则自动造数 ======
Future<void> _seedIfEmpty() async {
  final goalBox = Hive.box<m.Goal>(AppBoxes.goal);
  final taskBox = Hive.box<m.Task>(AppBoxes.task);
  final logBox  = Hive.box<m.DailyLog>(AppBoxes.dailyLog);

  if (goalBox.isEmpty && taskBox.isEmpty && logBox.isEmpty) {
    final g = m.Goal(title: '通过 FP2', description: '两个月内通过考试', priority: 1);
    final gKey = await goalBox.add(g);

    final now = DateTime.now();
    await taskBox.add(m.Task(title: '晨跑 3km', goalId: gKey, startAt: now, done: true));
    await taskBox.add(m.Task(title: '复习章节 5', goalId: gKey, startAt: now));
    await taskBox.add(m.Task(title: '错题整理 30min', goalId: gKey, startAt: now.add(const Duration(days: 1))));

    for (int i = 0; i < 3; i++) {
      final d = DateTime(now.year, now.month, now.day - i, 10, 0, 0);
      await logBox.add(m.DailyLog(
        date: d,
        content: i == 0 ? '今天状态不错，完成关键任务。' : (i == 1 ? '注意休息，下午效率低。' : '需要更早开始专注时段。'),
        goalId: gKey,
        minutes: 60 * (i + 1),
      ));
    }
  }
}


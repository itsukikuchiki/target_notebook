import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/hive_init.dart';

import 'providers/nav_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/sub_goal_provider.dart';
import 'providers/task_provider.dart';
import 'providers/daily_log_provider.dart';
import 'providers/user_provider.dart';
import 'providers/ai_breakdown_provider.dart';

import 'adapters/goal_adapter.dart' as goal_vm;
import 'adapters/task_adapter.dart' as task_vm;
import 'adapters/dailylog_adapter.dart' as log_vm;
import 'adapters/goal_tree_adapter.dart';

import 'services/ai_service.dart';
import 'services/notification_local_service.dart';

import 'models/goal.dart' as m;
import 'models/task.dart' as m;
import 'models/daily_log.dart' as m;

import 'app.dart';
import 'pages/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _loadDotEnvSafe();

  // 1) Hive
  await initHive();

  // 2) Providers（先创建实例）
  final nav = NavProvider();
  final userP = UserProvider();

  final goalP = GoalProvider();
  final subGoalP = SubGoalProvider();
  final taskP = TaskProvider();
  final logP = DailyLogProvider();

  // 2.1) Nav load
  await nav.load();

  // 2.2) Notification
  final notification = NotificationLocalService();
  await notification.init();

  // 2.3) init 顺序：User -> 业务数据
  await userP.init();

  await goalP.init();
  await subGoalP.init();

  // ✅ 关键：把 notification 传进 init（不要先 bind 再 init）
  await taskP.init(notification: notification);

  await logP.init();

  // 3) Seed（仅首次）
  await _seedIfEmpty();

  // 4) UI Adapters
  final goalVM = goal_vm.GoalAdapter(goalP, taskP);
  final taskVM = task_vm.TaskAdapter(taskP);
  final logVM = log_vm.DailyLogAdapter(logP);
  final goalTreeVM = GoalTreeAdapter(goalP, subGoalP, taskP);

  // 5) AI
  final apiKey = dotenv.maybeGet('OPENAI_API_KEY') ?? '';
  final aiService = AiService(apiKey: apiKey);

  final aiBreakdownP = AiBreakdownProvider(
    ai: aiService,
    goalProvider: goalP,
    subGoalProvider: subGoalP,
    taskProvider: taskP,
  );

  // 6) Run
  runApp(
    MultiProvider(
      providers: [
        Provider<NotificationLocalService>.value(value: notification),
        ChangeNotifierProvider.value(value: nav),
        ChangeNotifierProvider.value(value: userP),

        ChangeNotifierProvider.value(value: goalP),
        ChangeNotifierProvider.value(value: subGoalP),
        ChangeNotifierProvider.value(value: taskP),
        ChangeNotifierProvider.value(value: logP),

        ChangeNotifierProvider.value(value: goalVM),
        ChangeNotifierProvider.value(value: taskVM),
        ChangeNotifierProvider.value(value: logVM),

        ChangeNotifierProvider.value(value: goalTreeVM),
        ChangeNotifierProvider.value(value: aiBreakdownP),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const SplashPage(),
        routes: {
          '/home': (_) => const TargetNotebookApp(),
        },
      ),
    ),
  );
}

Future<void> _loadDotEnvSafe() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
}

Future<void> _seedIfEmpty() async {
  final goalBox = Hive.box<m.Goal>(AppBoxes.goal);
  final taskBox = Hive.box<m.Task>(AppBoxes.task);
  final logBox = Hive.box<m.DailyLog>(AppBoxes.dailyLog);

  if (goalBox.isNotEmpty || taskBox.isNotEmpty || logBox.isNotEmpty) return;

  final g = m.Goal(
    title: '通过 FP2',
    description: '两个月内通过考试',
    priority: 1,
    color: 0xFF5C6BC0,
  );
  final gKey = await goalBox.add(g);

  final now = DateTime.now();

  await taskBox.add(
    m.Task(
      title: '晨跑 3km',
      goalId: gKey,
      startAt: now,
      done: true,
      priority: 2,
    ),
  );

  await taskBox.add(
    m.Task(
      title: '复习章节 5',
      goalId: gKey,
      startAt: now,
      priority: 1,
    ),
  );

  await taskBox.add(
    m.Task(
      title: '错题整理 30min',
      goalId: gKey,
      startAt: now.add(const Duration(days: 1)),
      priority: 3,
    ),
  );

  for (int i = 0; i < 3; i++) {
    final d = DateTime(now.year, now.month, now.day - i, 10, 0);
    await logBox.add(
      m.DailyLog(
        date: d,
        content: i == 0
            ? '今天状态不错，完成关键任务。'
            : (i == 1 ? '注意休息，下午效率低。' : '需要更早开始专注时段。'),
        goalId: gKey,
        minutes: 60 * (i + 1),
      ),
    );
  }
}


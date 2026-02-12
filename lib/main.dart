import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 1) Hive 初始化
import 'core/hive_init.dart';

// 2) Provider 层
import 'providers/nav_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/sub_goal_provider.dart';
import 'providers/task_provider.dart';
import 'providers/daily_log_provider.dart';

// 🆕 AI Provider
import 'providers/ai_breakdown_provider.dart';

// 3) UI Adapters
import 'adapters/goal_adapter.dart' as goal_vm;
import 'adapters/task_adapter.dart' as task_vm;
import 'adapters/dailylog_adapter.dart' as log_vm;
import 'adapters/goal_tree_adapter.dart';

// 🆕 AI Service
import 'services/ai_service.dart';

// 4) 模型（仅为种子数据所需）
import 'models/goal.dart' as m;
import 'models/task.dart' as m;
import 'models/daily_log.dart' as m;

// 5) App & Pages
import 'app.dart';
import 'pages/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // =========================
  // 0) .env（可选，缺失不崩）
  // =========================
  await _loadDotEnvSafe();

  // =========================
  // 1) Hive 初始化
  // =========================
  await initHive();

  // =========================
  // 2) Providers
  // =========================
  final goalP = GoalProvider();
  final subGoalP = SubGoalProvider();
  final taskP = TaskProvider();
  final logP = DailyLogProvider();

  await goalP.init();
  await subGoalP.init();
  await taskP.init();
  await logP.init();

  // =========================
  // 3) 种子数据（仅首次）
  // =========================
  await _seedIfEmpty();

  // =========================
  // 4) UI Adapters
  // =========================
  final nav = NavProvider();
  final goalVM = goal_vm.GoalAdapter(goalP, taskP);
  final taskVM = task_vm.TaskAdapter(taskP);
  final logVM = log_vm.DailyLogAdapter(logP);

  // 目标树 Adapter（My Journey / Insight / Calendar 共用）
  final goalTreeVM = GoalTreeAdapter(goalP, subGoalP, taskP);

  // =========================
  // 5) AI Service & Provider（🆕）
  // =========================
  // 没有 key 也不崩：AiService 内部会抛错 → AiBreakdownProvider catch 后走 fallback
  final apiKey = dotenv.maybeGet('OPENAI_API_KEY') ?? '';
  final aiService = AiService(apiKey: apiKey);

  final aiBreakdownP = AiBreakdownProvider(
    ai: aiService,
    goalProvider: goalP,
    subGoalProvider: subGoalP,
    taskProvider: taskP,
  );

  // =========================
  // 6) 注入 & 启动
  // =========================
  runApp(
    MultiProvider(
      providers: [
        // navigation
        ChangeNotifierProvider.value(value: nav),

        // core providers
        ChangeNotifierProvider.value(value: goalP),
        ChangeNotifierProvider.value(value: subGoalP),
        ChangeNotifierProvider.value(value: taskP),
        ChangeNotifierProvider.value(value: logP),

        // ui adapters
        ChangeNotifierProvider.value(value: goalVM),
        ChangeNotifierProvider.value(value: taskVM),
        ChangeNotifierProvider.value(value: logVM),

        // goal tree
        ChangeNotifierProvider.value(value: goalTreeVM),

        // 🆕 AI
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
  } catch (_) {
    // .env 不存在/读取失败都不影响启动
    // 正式版建议改为后端代理，不在客户端存 key
  }
}

// =======================================================
// 仅本地演示用的种子数据（首次启动）
// =======================================================
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


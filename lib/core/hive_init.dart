import 'package:hive_flutter/hive_flutter.dart';

import '../models/kpi.dart';
import '../models/goal.dart';
import '../models/sub_goal.dart';
import '../models/task.dart';
import '../models/daily_log.dart';

// 🆕 W6: 用户模型（包含 enum adapter）
import '../models/app_user.dart';

class AppBoxes {
  static const goal = 'goalBox';
  static const subGoal = 'subGoalBox';
  static const task = 'taskBox';
  static const dailyLog = 'dailyLogBox';

  // 🆕 W6
  static const user = 'userBox';
}

Future<void> initHive() async {
  await Hive.initFlutter();

  // =============================
  // 注册 TypeAdapters（只注册一次）
  // =============================
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(KPIAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(GoalAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(SubGoalAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(TaskAdapter());
  if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(DailyLogAdapter());

  // 🆕 W6: 用户
  // AppUser: typeId = 6
  if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(AppUserAdapter());

  // AuthProviderType(enum): typeId = 7
  if (!Hive.isAdapterRegistered(7)) {
    Hive.registerAdapter(AuthProviderTypeAdapter());
  }

  // =============================
  // 打开 Boxes
  // =============================
  await Hive.openBox<Goal>(AppBoxes.goal);
  await Hive.openBox<SubGoal>(AppBoxes.subGoal);
  await Hive.openBox<Task>(AppBoxes.task);
  await Hive.openBox<DailyLog>(AppBoxes.dailyLog);

  // 🆕 W6: 用户 Box
  await Hive.openBox<AppUser>(AppBoxes.user);
}


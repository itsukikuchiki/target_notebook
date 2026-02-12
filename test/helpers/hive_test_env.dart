import 'dart:io';

import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/kpi.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/sub_goal.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/models/daily_log.dart';

Directory? _hiveTestDir;
bool _hiveInited = false;

/// Hive 2.2.3 没有 Hive.boxNames，所以我们自己追踪 test 中打开过的 boxes。
final Set<String> _openedBoxNames = <String>{};

/// ---------------------------------------------------------------------------
/// 公共工具：清空 Hive boxes（flutter_test_config.dart 在用）
/// ---------------------------------------------------------------------------
Future<void> clearHiveBoxes() async {
  // 你项目固定的 box 名（即使不是通过 helper 打开的，也尝试清）
  final fixed = <String>{
    AppBoxes.goal,
    AppBoxes.subGoal,
    AppBoxes.task,
    AppBoxes.dailyLog,
  };

  final names = <String>{
    ...fixed,
    ..._openedBoxNames,
  }.toList();

  for (final name in names) {
    try {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).clear();
      }
    } catch (_) {}
  }
}

/// ---------------------------------------------------------------------------
/// 推荐：通过 helper 打开 box（会自动记录，方便 clearHiveBoxes 清理）
/// ---------------------------------------------------------------------------
Future<Box<T>> openTestBox<T>(String name) async {
  _openedBoxNames.add(name);
  if (Hive.isBoxOpen(name)) return Hive.box<T>(name);
  return Hive.openBox<T>(name);
}

/// ---------------------------------------------------------------------------
/// 旧测试兼容 API：initHiveTest / disposeHiveTest
/// ---------------------------------------------------------------------------
Future<Directory> initHiveTest() async {
  if (_hiveInited && _hiveTestDir != null) return _hiveTestDir!;

  final dir = await Directory.systemTemp.createTemp('target_notebook_hive_test_');
  _hiveTestDir = dir;

  Hive.init(dir.path);

  // ignore: avoid_print
  print('[hive_test_env] Hive.init at ${dir.path}');

  _registerAdaptersIfNeeded();

  // ignore: avoid_print
  print('[hive_test_env] adapters registered');

  _hiveInited = true;
  return dir;
}

Future<void> disposeHiveTest(Directory dir) async {
  try {
    await Hive.close();
  } catch (_) {}

  if (await dir.exists()) {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }

  if (_hiveTestDir?.path == dir.path) {
    _hiveTestDir = null;
    _hiveInited = false;
    _openedBoxNames.clear();
  }
}

/// ---------------------------------------------------------------------------
/// 你现在 tests 里主要在用的 API：保持不变
/// ---------------------------------------------------------------------------
Future<void> ensureHiveReady() async {
  await initHiveTest();
}

/// ---------------------------------------------------------------------------
/// 🔑 关键：完全复刻 lib/core/hive_init.dart 里的 adapter 注册逻辑
/// （但不调用 Hive.initFlutter，不 open boxes）
/// ---------------------------------------------------------------------------
void _registerAdaptersIfNeeded() {
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(KPIAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(GoalAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(SubGoalAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(TaskAdapter());
  if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(DailyLogAdapter());
}


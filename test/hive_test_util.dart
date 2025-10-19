import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;

// === 模型适配器 ===
import 'package:target_notebook/models/kpi.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/sub_goal.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/models/daily_log.dart';

/// 初始化临时 Hive 环境（测试专用）
///
/// 创建一个临时目录并注册所有模型适配器，
/// 返回该目录对象以便后续删除。
Future<Directory> initHiveTest() async {
  // 创建临时目录
  final dir = await Directory.systemTemp.createTemp('hive_test_');

  // 初始化 Hive 根目录
  Hive.init(p.normalize(dir.path));

  // 防重复注册：确保并行测试不会重复 Adapter ID 冲突
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(KPIAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(GoalAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(SubGoalAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(TaskAdapter());
  if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(DailyLogAdapter());

  return dir;
}

/// 关闭 Hive 并删除临时目录
Future<void> disposeHiveTest(Directory dir) async {
  try {
    await Hive.close();
  } catch (_) {}
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
}


import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:target_notebook/models/kpi.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/sub_goal.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/models/daily_log.dart';

Future<Directory> initHiveTest() async {
  final dir = await Directory.systemTemp.createTemp('hive_test_');
  Hive
    ..init(dir.path)
    ..registerAdapter(KPIAdapter())
    ..registerAdapter(GoalAdapter())
    ..registerAdapter(SubGoalAdapter())
    ..registerAdapter(TaskAdapter())
    ..registerAdapter(DailyLogAdapter());
  return dir;
}

Future<void> disposeHiveTest(Directory dir) async {
  await Hive.close();
  if (await dir.exists()) await dir.delete(recursive: true);
}


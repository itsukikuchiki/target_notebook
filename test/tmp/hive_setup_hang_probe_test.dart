import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/kpi.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/sub_goal.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/models/daily_log.dart';
import 'package:target_notebook/models/app_user.dart';

import '../helpers/hive_test_env.dart';

void _registerAdaptersIfNeededInline() {
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(KPIAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(GoalAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(SubGoalAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(TaskAdapter());
  if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(DailyLogAdapter());
  if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(AppUserAdapter());
  if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(AuthProviderTypeAdapter());
}

Future<Box<T>> _openTestBoxInline<T>(String name) async {
  if (Hive.isBoxOpen(name)) return Hive.box<T>(name);
  return Hive.openBox<T>(name);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('INLINE: step-by-step flow matching HiveTestEnv.setUp', () async {
    print('STEP S1: enter test');

    print('STEP S2: before inline envRefCount increment (matches HiveTestEnv.setUp sync step)');
    print('STEP S3: after inline envRefCount increment (simulated)');

    print('STEP S4: before ensureHiveReady (inlined)');

    print('STEP S5: before initHiveTest if-check (_hiveInited/_hiveTestDir simulated)');
    print('STEP S6: after initHiveTest if-check (continuing create temp dir path)');

    print('STEP S7: before Directory.systemTemp.createTemp(target_notebook_hive_test_)');
    final dir = await Directory.systemTemp.createTemp('target_notebook_hive_test_');
    print('STEP S8: after Directory.systemTemp.createTemp path=${dir.path}');

    print('STEP S9: before Hive.init(dir.path)');
    Hive.init(dir.path);
    print('STEP S10: after Hive.init(dir.path)');

    print('STEP S11: before _registerAdaptersIfNeeded (inlined sync)');
    _registerAdaptersIfNeededInline();
    print('STEP S12: after _registerAdaptersIfNeeded (inlined sync)');

    print('STEP S13: after ensureHiveReady (inlined)');

    print('STEP S14: before openTestBox goal');
    await _openTestBoxInline<Goal>(AppBoxes.goal);
    print('STEP S15: after openTestBox goal');

    print('STEP S16: before openTestBox subGoal');
    await _openTestBoxInline<SubGoal>(AppBoxes.subGoal);
    print('STEP S17: after openTestBox subGoal');

    print('STEP S18: before openTestBox task');
    await _openTestBoxInline<Task>(AppBoxes.task);
    print('STEP S19: after openTestBox task');

    print('STEP S20: before openTestBox dailyLog');
    await _openTestBoxInline<DailyLog>(AppBoxes.dailyLog);
    print('STEP S21: after openTestBox dailyLog');

    print('STEP S22: before openTestBox user');
    await _openTestBoxInline<AppUser>(AppBoxes.user);
    print('STEP S23: after openTestBox user');

    print('STEP S24: inline setup sequence done');
  });

  test('CONTROL: direct HiveTestEnv.setUp()', () async {
    print('STEP C1: before HiveTestEnv.setUp()');
    await HiveTestEnv.setUp();
    print('STEP C2: after HiveTestEnv.setUp()');
  });
}

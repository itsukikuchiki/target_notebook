import 'dart:io';
import 'package:test/test.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/providers/task_provider.dart';
import '../hive_test_util.dart';
import '../helpers/hive_test_env.dart';

void main() {
  late Directory dir;
  late TaskProvider tp;

  setUp(() async {
    dir = await initHiveTest();
    await Hive.openBox<Task>(AppBoxes.task);
    tp = TaskProvider();
    await tp.init();
  });

  tearDown(() async {
    await disposeHiveTest(dir);
  });

  test('top3ForDate 优先返回 pinned 任务，不足自动补未完成', () async {
    final today = DateTime(2025, 11, 3, 9);

    // 5 个任务，其中 2 个 pinned，1 个已完成
    final keys = <int>[];
    keys.add(await Hive.box<Task>(AppBoxes.task).add(Task(title: 'A', startAt: today))); // 补位候选
    keys.add(await Hive.box<Task>(AppBoxes.task).add(Task(title: 'B', startAt: today, isTodayTop3: true))); // pinned
    keys.add(await Hive.box<Task>(AppBoxes.task).add(Task(title: 'C', startAt: today, isTodayTop3: true))); // pinned
    keys.add(await Hive.box<Task>(AppBoxes.task).add(Task(title: 'D', startAt: today, done: true))); // 完成的，不应进入 top3
    keys.add(await Hive.box<Task>(AppBoxes.task).add(Task(title: 'E', startAt: today))); // 补位候选

    final top = tp.top3ForDate(today);
    expect(top.length, 3);

    // 前两名应包含 pinned（顺序无强制，但必须都在里头）
    final titles = top.map((t) => t.title).toSet();
    expect(titles.containsAll({'B', 'C'}), isTrue);

    // 第三个来自未完成非 pinned（A 或 E）
    expect(titles.intersection({'A', 'E'}).isNotEmpty, isTrue);
    // 完成的 D 不应出现
    expect(titles.contains('D'), isFalse);
  });

  test('setPinnedTop3 生效；setTop3Order 记录当天排序', () async {
    final today = DateTime(2025, 11, 3, 9);

    final box = Hive.box<Task>(AppBoxes.task);
    final k1 = await box.add(Task(title: 'T1', startAt: today));
    final k2 = await box.add(Task(title: 'T2', startAt: today));
    final k3 = await box.add(Task(title: 'T3', startAt: today));
    final k4 = await box.add(Task(title: 'T4', startAt: today));

    // 固定两个
    await tp.setPinnedTop3(k2, true);
    await tp.setPinnedTop3(k3, true);

    var top = tp.top3ForDate(today);
    expect(top.map((e) => e.key).toSet().containsAll({k2, k3}), isTrue);

    // 设定当天拖拽顺序：k3, k2, k1
    tp.setTop3Order(today, [k3, k2, k1]);
    top = tp.top3ForDate(today);

    // 与记录顺序一致（注意：top3 只取 3 个）
    expect(top[0].key, equals(k3));
    expect(top[1].key, equals(k2));
    expect(top[2].key, equals(k1));

    // 取消固定后，仍保留排序规则（若仍在 top3）
    await tp.setPinnedTop3(k2, false);
    top = tp.top3ForDate(today);
    // 可能补位变化，但若 k2 仍未完成在当日，排序仍按记录应用
    expect(top.first.key, anyOf(k3, k2));
  });

  test('toggleTaskDone 能正确切换完成状态并影响排序', () async {
    final today = DateTime(2025, 11, 3, 9);
    final box = Hive.box<Task>(AppBoxes.task);

    final k1 = await box.add(Task(title: 'X', startAt: today));
    final k2 = await box.add(Task(title: 'Y', startAt: today));

    // 初始未完成 → top3 应包含 X,Y
    var list = tp.tasksForDate(today);
    expect(list.any((t) => t.key == k1), isTrue);

    await tp.toggleTaskDone(k1, true); // 完成 X
    list = tp.tasksForDate(today);
    // 完成项应排在后面
    final idxX = list.indexWhere((t) => t.key == k1);
    final idxY = list.indexWhere((t) => t.key == k2);
    expect(idxX, greaterThan(idxY));
  });
}


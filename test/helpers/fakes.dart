import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ✅ 分开前缀，避免重复 as ui
import 'package:target_notebook/adapters/goal_adapter.dart' as goal_ui;
import 'package:target_notebook/adapters/task_adapter.dart' as task_ui;
import 'package:target_notebook/adapters/dailylog_adapter.dart' as log_ui;

// ✅ 引入真实 Provider 类型（构造 super 的占位，不会触发 Hive）
import 'package:target_notebook/providers/goal_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';
import 'package:target_notebook/providers/daily_log_provider.dart';

// ===== 占位 Provider（不初始化 Hive、不做任何事） =====
class _DummyGoalProvider extends GoalProvider {}

class _DummyTaskProvider extends TaskProvider {}

class _DummyDailyLogProvider extends DailyLogProvider {}

// ====== 公共：构造 GoalVM 便捷函数 ======
goal_ui.GoalVM goal(
  int id,
  String title,
  double progress,
  int done,
  int total,
) =>
    goal_ui.GoalVM(
      id: id,
      title: title,
      progress: progress,
      tasksCount: total,
      doneCount: done,
      // ✅ W5 新增必填
      priority: 3,
    );

// ====== Fake：GoalAdapter（类型上 = 真实 GoalAdapter）======
class FakeGoalAdapter extends goal_ui.GoalAdapter {
  FakeGoalAdapter() : super(_DummyGoalProvider(), _DummyTaskProvider());

  List<goal_ui.GoalVM> _list = const [];

  set seed(List<goal_ui.GoalVM> v) {
    _list = v;
    notifyListeners();
  }

  @override
  List<goal_ui.GoalVM> get goalsVM => _list;
}

// ====== Fake：TaskAdapter（类型上 = 真实 TaskAdapter）======
class FakeTaskVM {
  final int id;
  final String title;
  final DateTime date;
  final bool done;

  FakeTaskVM(this.id, this.title, this.date, this.done);
}

class FakeTaskAdapter extends task_ui.TaskAdapter {
  FakeTaskAdapter() : super(_DummyTaskProvider());

  final Map<DateTime, List<FakeTaskVM>> _table = {};

  // 注入某天的任务
  void seedForDay(DateTime day, List<FakeTaskVM> tasks) {
    _table[DateUtils.dateOnly(day)] = tasks;
    notifyListeners();
  }

  @override
  List<task_ui.TaskVM> tasksForDate(DateTime d) {
    final list = _table[DateUtils.dateOnly(d)] ?? const <FakeTaskVM>[];
    return <task_ui.TaskVM>[
      for (final t in list) task_ui.TaskVM(t.id, t.title, t.date, t.done),
    ];
  }

  // 如果你项目里没有 tasksForDay，就别加 @override（避免 mismatch）
  List<task_ui.TaskVM> tasksForDay(DateTime d) => tasksForDate(d);

  @override
  List<task_ui.TaskVM> top3ForDate(DateTime d) {
    final list = tasksForDate(d);
    if (list.length <= 3) return list;
    return list.take(3).toList();
  }

  @override
  Future<void> toggleTaskDone(int id, bool v) async {
    notifyListeners();
  }
}

// ====== 公共：反思 VM 的公开桩类型（不要用私有前缀 _，否则跨文件不可见）======
class ReflectionStub implements log_ui.ReflectionVM {
  @override
  final DateTime date;

  @override
  final String content;

  @override
  final int minutes;

  const ReflectionStub(
    this.date,
    this.content, {
    this.minutes = 0,
  });
}

// ====== Fake：DailyLogAdapter（类型上 = 真实 DailyLogAdapter）======
class FakeDailyLogAdapter extends log_ui.DailyLogAdapter {
  FakeDailyLogAdapter() : super(_DummyDailyLogProvider());

  log_ui.WeeklyVM _weekly =
      const log_ui.WeeklyVM({}, 0.0, '本周还没有记录投入时长，开始第一条吧！');
  List<log_ui.ReflectionVM> _refs = const [];

  set weeklySeed(log_ui.WeeklyVM v) {
    _weekly = v;
    notifyListeners();
  }

  set reflectionsSeed(List<log_ui.ReflectionVM> v) {
    _refs = v;
    notifyListeners();
  }

  @override
  log_ui.WeeklyVM weeklyStats({DateTime? now}) => _weekly;

  @override
  List<log_ui.ReflectionVM> latestReflections({int limit = 10}) => _refs;
}

// ====== Finder 辅助 ======
Finder plusTile(String text) => find.text(text);


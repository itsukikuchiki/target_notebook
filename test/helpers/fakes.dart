import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ✅ 引入真实 UI 适配器类型（注意不要引入 models 下的同名类型）
import 'package:target_notebook/adapters/goal_adapter.dart' as ui;
import 'package:target_notebook/adapters/task_adapter.dart' as ui;
import 'package:target_notebook/adapters/dailylog_adapter.dart' as ui;

// ✅ 引入真实 Provider 类型（构造 super 的占位，不会触发 Hive）
import 'package:target_notebook/providers/goal_provider.dart';
import 'package:target_notebook/providers/task_provider.dart';
import 'package:target_notebook/providers/daily_log_provider.dart';

// ===== 占位 Provider（不初始化 Hive、不做任何事） =====
class _DummyGoalProvider extends GoalProvider {}
class _DummyTaskProvider extends TaskProvider {}
class _DummyDailyLogProvider extends DailyLogProvider {}

// ====== 公共：构造 GoalVM 便捷函数 ======
ui.GoalVM goal(int id, String title, double progress, int done, int total) =>
    ui.GoalVM(
      id: id,
      title: title,
      progress: progress,
      tasksCount: total,
      doneCount: done,
    );

// ====== Fake：GoalAdapter（类型上 = 真实 GoalAdapter）======
class FakeGoalAdapter extends ui.GoalAdapter {
  FakeGoalAdapter() : super(_DummyGoalProvider(), _DummyTaskProvider());

  List<ui.GoalVM> _list = const [];
  set seed(List<ui.GoalVM> v) {
    _list = v;
    notifyListeners();
  }

  @override
  List<ui.GoalVM> get goalsVM => _list;
}

// ====== Fake：TaskAdapter（类型上 = 真实 TaskAdapter）======
class FakeTaskVM {
  final int id;
  final String title;
  final DateTime date;
  final bool done;
  FakeTaskVM(this.id, this.title, this.date, this.done);
}

class FakeTaskAdapter extends ui.TaskAdapter {
  FakeTaskAdapter() : super(_DummyTaskProvider());

  final Map<DateTime, List<FakeTaskVM>> _table = {};

  // 注入某天的任务
  void seedForDay(DateTime day, List<FakeTaskVM> tasks) {
    _table[DateUtils.dateOnly(day)] = tasks;
    notifyListeners();
  }

  @override
  List<ui.TaskVM> tasksForDate(DateTime d) {
    final list = _table[DateUtils.dateOnly(d)] ?? const <FakeTaskVM>[];
    // ✅ TaskVM 需要四个位置参数：id, title, date, done
    final result = <ui.TaskVM>[
      for (final t in list) ui.TaskVM(t.id, t.title, t.date, t.done),
    ];
    return result;
  }

  @override
  Future<void> toggleTaskDone(int id, bool v) async {
    // 简化：仅通知刷新
    notifyListeners();
  }
}

// ====== 公共：反思 VM 的公开桩类型（不要用私有前缀 _，否则跨文件不可见）======
class ReflectionStub implements ui.ReflectionVM {
  @override
  final DateTime date;
  @override
  final String content;
  const ReflectionStub(this.date, this.content);
}

// ====== Fake：DailyLogAdapter（类型上 = 真实 DailyLogAdapter）======
class FakeDailyLogAdapter extends ui.DailyLogAdapter {
  FakeDailyLogAdapter() : super(_DummyDailyLogProvider(), _DummyTaskProvider());

  ui.WeeklyStatsVM _weekly =
      const ui.WeeklyStatsVM({}, 0.0, '本周还没有记录投入时长，开始第一条吧！');
  List<ui.ReflectionVM> _refs = const [];

  set weeklySeed(ui.WeeklyStatsVM v) {
    _weekly = v;
    notifyListeners();
  }

  set reflectionsSeed(List<ui.ReflectionVM> v) {
    _refs = v;
    notifyListeners();
  }

  @override
  ui.WeeklyStatsVM weeklyStats() => _weekly;

  @override
  List<ui.ReflectionVM> latestReflections() => _refs;
}

// ====== Finder 辅助 ======
Finder plusTile(String text) => find.widgetWithText(ListTile, text);


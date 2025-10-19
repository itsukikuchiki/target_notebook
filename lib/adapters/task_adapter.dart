import 'package:flutter/foundation.dart';
import '../providers/task_provider.dart' as phase1;
import 'package:flutter/material.dart'; // for UniqueKey as fallback

class TaskVM {
  final int id;           // Hive key
  final String title;
  final DateTime date;    // from startAt or endAt
  final bool done;
  const TaskVM(this.id, this.title, this.date, this.done);
}

class TaskAdapter extends ChangeNotifier {
  final phase1.TaskProvider src;
  TaskAdapter(this.src) { src.addListener(notifyListeners); }

  List<TaskVM> tasksForDate(DateTime day) {
    final list = src.tasksForDay(day);
    return list.map((t) {
      final id = _safeKey(t) ?? UniqueKey().hashCode;
      final date = _firstNonNullDate(t) ?? day;
      return TaskVM(id, t.title, date, t.done);
    }).toList();
  }

  Future<void> toggleTaskDone(int taskId, bool _) async {
    // Phase1 只有 toggleDone(key)，不区分 true/false；UI 会刷新为最终状态
    await src.toggleDone(taskId);
    notifyListeners();
  }
}

int? _safeKey(Object o) {
  try { final k = (o as dynamic).key; if (k is int) return k; } catch (_) {}
  return null;
}

DateTime? _firstNonNullDate(Object t) {
  try { final sa = (t as dynamic).startAt; if (sa is DateTime) return sa; } catch (_) {}
  try { final ea = (t as dynamic).endAt;   if (ea is DateTime) return ea; } catch (_) {}
  return null;
}


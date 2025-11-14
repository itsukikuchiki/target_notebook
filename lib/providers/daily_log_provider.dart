import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../core/hive_init.dart';
import '../models/daily_log.dart';
import '../utils/hive_initializer.dart';

class DailyLogProvider extends ChangeNotifier {
  late Box<DailyLog> _logBox;

  /// 可注入 [logBox]；默认打开 [AppBoxes.dailyLog]
  Future<void> init({Box<DailyLog>? logBox, String boxName = AppBoxes.dailyLog}) async {
    _logBox = logBox ?? await ensureTypedBox<DailyLog>(boxName);
  }

  /// 全量（Adapter/Insight 会直接读取）
  List<DailyLog> all() => _logBox.values.toList();

  /// 新增一条快速日志
  Future<int> addQuickLog({
    required DateTime date,
    required String content,
    required int minutes,
    int? taskId,
    int? goalId,
  }) async {
    final log = DailyLog(
      date: date,
      content: content,
      minutes: minutes,
      taskId: taskId,
      goalId: goalId,
    );
    final k = await _logBox.add(log);
    notifyListeners();
    return k;
  }

  /// 删除
  Future<void> delete(int key) async {
    await _logBox.delete(key);
    notifyListeners();
  }

  /// 更新
  Future<void> update(int key, DailyLog patch) async {
    final l = _logBox.get(key);
    if (l == null) return;
    l
      ..date = patch.date
      ..content = patch.content
      ..minutes = patch.minutes
      ..taskId = patch.taskId
      ..goalId = patch.goalId;
    await l.save();
    notifyListeners();
  }
}


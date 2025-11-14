import 'package:hive/hive.dart';
part 'task.g.dart';

@HiveType(typeId: 4)
class Task extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String? note;

  @HiveField(2)
  int? goalId;

  @HiveField(3)
  int? subGoalId;

  @HiveField(4)
  DateTime? startAt;

  @HiveField(5)
  DateTime? endAt;

  @HiveField(6)
  bool done;

  /// 今日三件事（Pinned）
  @HiveField(7)
  bool isTodayTop3;

  Task({
    required this.title,
    this.note,
    this.goalId,
    this.subGoalId,
    this.startAt,
    this.endAt,
    this.done = false,
    this.isTodayTop3 = false,
  });

  // === JSON 序列化（用于导入导出） ===
  Map<String, dynamic> toMap() => {
        'title': title,
        'note': note,
        'goalId': goalId,
        'subGoalId': subGoalId,
        'startAt': startAt?.toIso8601String(),
        'endAt': endAt?.toIso8601String(),
        'done': done,
        'isTodayTop3': isTodayTop3,
      };

  static Task fromMap(Map<String, dynamic> m) => Task(
        title: m['title'] as String,
        note: m['note'] as String?,
        goalId: m['goalId'] as int?,
        subGoalId: m['subGoalId'] as int?,
        startAt: (m['startAt'] as String?) != null ? DateTime.parse(m['startAt'] as String) : null,
        endAt: (m['endAt'] as String?) != null ? DateTime.parse(m['endAt'] as String) : null,
        done: (m['done'] as bool?) ?? false,
        isTodayTop3: (m['isTodayTop3'] as bool?) ?? false,
      );
}


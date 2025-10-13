import 'package:hive/hive.dart';
part 'daily_log.g.dart';

@HiveType(typeId: 5)
class DailyLog extends HiveObject {
  @HiveField(0)
  DateTime date; // JST day

  @HiveField(1)
  String content;

  @HiveField(2)
  int? goalId;

  @HiveField(3)
  int? taskId;

  @HiveField(4)
  int minutes; // 当天投入时长

  DailyLog({
    DateTime? date,
    required this.content,
    this.goalId,
    this.taskId,
    this.minutes = 0,
  }) : date = date ?? DateTime.now();

  // ----- JSON -----
  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'content': content,
        'goalId': goalId,
        'taskId': taskId,
        'minutes': minutes,
      };

  static DailyLog fromMap(Map<String, dynamic> m) => DailyLog(
        date: DateTime.parse(m['date'] as String),
        content: m['content'] as String,
        goalId: m['goalId'] as int?,
        taskId: m['taskId'] as int?,
        minutes: (m['minutes'] as int?) ?? 0,
      );
}


import 'package:hive/hive.dart';
part 'task.g.dart';

@HiveType(typeId: 4)
class Task extends HiveObject {
  @HiveField(0)
  int? goalId;

  @HiveField(1)
  int? subGoalId;

  @HiveField(2)
  String title;

  @HiveField(3)
  String? note;

  @HiveField(4)
  DateTime? startAt;

  @HiveField(5)
  DateTime? endAt;

  @HiveField(6)
  bool done;

  Task({
    this.goalId,
    this.subGoalId,
    required this.title,
    this.note,
    this.startAt,
    this.endAt,
    this.done = false,
  });
}

Map<String, dynamic> toMap() => {
  'goalId': goalId,
  'subGoalId': subGoalId,
  'title': title,
  'note': note,
  'startAt': startAt?.toIso8601String(),
  'endAt': endAt?.toIso8601String(),
  'done': done,
};
static Task fromMap(Map<String, dynamic> m) => Task(
  goalId: m['goalId'] as int?,
  subGoalId: m['subGoalId'] as int?,
  title: m['title'] as String,
  note: m['note'] as String?,
  startAt: (m['startAt'] as String?) != null ? DateTime.parse(m['startAt'] as String) : null,
  endAt: (m['endAt'] as String?) != null ? DateTime.parse(m['endAt'] as String) : null,
  done: m['done'] as bool? ?? false,
);


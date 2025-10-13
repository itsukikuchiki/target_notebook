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


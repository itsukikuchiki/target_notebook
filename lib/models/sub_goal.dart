import 'package:hive/hive.dart';
part 'sub_goal.g.dart';

@HiveType(typeId: 3)
class SubGoal extends HiveObject {
  @HiveField(0)
  int goalId; // 关联父 Goal

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  int orderIndex; // 用于排序

  SubGoal({
    required this.goalId,
    required this.title,
    this.description,
    this.orderIndex = 0,
  });
}

Map<String, dynamic> toMap() => {
  'goalId': goalId,
  'title': title,
  'description': description,
  'orderIndex': orderIndex,
};
static SubGoal fromMap(Map<String, dynamic> m) => SubGoal(
  goalId: m['goalId'] as int,
  title: m['title'] as String,
  description: m['description'] as String?,
  orderIndex: m['orderIndex'] as int? ?? 0,
);


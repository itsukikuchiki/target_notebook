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

  /// 用于排序（显式顺序）
  @HiveField(3)
  int orderIndex;

  // ===== W5 Additions (append-only for Hive safety) =====

  /// 优先度（1最高～5）
  @HiveField(4)
  int priority;

  /// 子目标颜色（可选，为 12/15 铺路）
  @HiveField(5)
  int? color;

  SubGoal({
    required this.goalId,
    required this.title,
    this.description,
    this.orderIndex = 0,
    this.priority = 3,
    this.color,
  });

  // ----- JSON -----
  Map<String, dynamic> toMap() => {
        'goalId': goalId,
        'title': title,
        'description': description,
        'orderIndex': orderIndex,
        'priority': priority,
        'color': color,
      };

  static SubGoal fromMap(Map<String, dynamic> m) => SubGoal(
        goalId: m['goalId'] as int,
        title: m['title'] as String,
        description: m['description'] as String?,
        orderIndex: (m['orderIndex'] as int?) ?? 0,
        priority: (m['priority'] as int?) ?? 3,
        color: m['color'] as int?,
      );
}


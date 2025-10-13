import 'package:hive/hive.dart';
import 'kpi.dart';
part 'goal.g.dart';

@HiveType(typeId: 2)
class Goal extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String? description;

  @HiveField(2)
  int priority; // 1(最高) ~ 5

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime? dueDate;

  @HiveField(5)
  List<KPI> kpis;

  Goal({
    required this.title,
    this.description,
    this.priority = 3,
    DateTime? createdAt,
    this.dueDate,
    List<KPI>? kpis,
  })  : createdAt = createdAt ?? DateTime.now(),
        kpis = kpis ?? [];
}


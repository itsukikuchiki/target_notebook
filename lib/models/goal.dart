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

Map<String, dynamic> toMap() => {
  'title': title,
  'description': description,
  'priority': priority,
  'createdAt': createdAt.toIso8601String(),
  'dueDate': dueDate?.toIso8601String(),
  'kpis': kpis.map((e) => e.toMap()).toList(),
};
static Goal fromMap(Map<String, dynamic> m) => Goal(
  title: m['title'] as String,
  description: m['description'] as String?,
  priority: m['priority'] as int? ?? 3,
  createdAt: DateTime.parse(m['createdAt'] as String),
  dueDate: (m['dueDate'] as String?) != null ? DateTime.parse(m['dueDate'] as String) : null,
  kpis: (m['kpis'] as List<dynamic>? ?? []).map((e) => KPI.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
);


import 'package:hive/hive.dart';
part 'kpi.g.dart';

@HiveType(typeId: 1)
class KPI extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  double targetValue;

  @HiveField(2)
  double currentValue;

  @HiveField(3)
  String unit; // e.g. "hrs", "%", "¥"

  @HiveField(4)
  String period; // e.g. "weekly", "monthly", "quarterly"

  KPI({
    required this.name,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.period,
  });
}


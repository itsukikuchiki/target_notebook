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

Map<String, dynamic> toMap() => {
  'name': name,
  'targetValue': targetValue,
  'currentValue': currentValue,
  'unit': unit,
  'period': period,
};
static KPI fromMap(Map<String, dynamic> m) => KPI(
  name: m['name'] as String,
  targetValue: (m['targetValue'] as num).toDouble(),
  currentValue: (m['currentValue'] as num).toDouble(),
  unit: m['unit'] as String,
  period: m['period'] as String,
);


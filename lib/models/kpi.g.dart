// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kpi.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class KPIAdapter extends TypeAdapter<KPI> {
  @override
  final int typeId = 1;

  @override
  KPI read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return KPI(
      name: fields[0] as String,
      targetValue: fields[1] as double,
      currentValue: fields[2] as double,
      unit: fields[3] as String,
      period: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, KPI obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.targetValue)
      ..writeByte(2)
      ..write(obj.currentValue)
      ..writeByte(3)
      ..write(obj.unit)
      ..writeByte(4)
      ..write(obj.period);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KPIAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

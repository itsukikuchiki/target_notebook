// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sub_goal.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SubGoalAdapter extends TypeAdapter<SubGoal> {
  @override
  final int typeId = 3;

  @override
  SubGoal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SubGoal(
      goalId: fields[0] as int,
      title: fields[1] as String,
      description: fields[2] as String?,
      orderIndex: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SubGoal obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.goalId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.orderIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubGoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

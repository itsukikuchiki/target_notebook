// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 4;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      title: fields[0] as String,
      note: fields[1] as String?,
      goalId: fields[2] as int?,
      subGoalId: fields[3] as int?,
      startAt: fields[4] as DateTime?,
      endAt: fields[5] as DateTime?,
      done: fields[6] as bool,
      isTodayTop3: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.note)
      ..writeByte(2)
      ..write(obj.goalId)
      ..writeByte(3)
      ..write(obj.subGoalId)
      ..writeByte(4)
      ..write(obj.startAt)
      ..writeByte(5)
      ..write(obj.endAt)
      ..writeByte(6)
      ..write(obj.done)
      ..writeByte(7)
      ..write(obj.isTodayTop3);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

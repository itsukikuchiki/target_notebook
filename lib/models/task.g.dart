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
      priority: fields[8] as int,
      isAllDay: fields[9] as bool,
      location: fields[10] as String?,
      participantEmailsRaw: fields[11] as String?,
      hasAlarm: fields[12] as bool,
      alarmAt: fields[13] as DateTime?,
      iconKey: fields[14] as String?,
      completion: fields[15] as double,
      deadline: fields[16] as DateTime?,
      photoPath: fields[17] as String?,
      color: fields[18] as int?,
      topic: fields[19] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(20)
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
      ..write(obj.isTodayTop3)
      ..writeByte(8)
      ..write(obj.priority)
      ..writeByte(9)
      ..write(obj.isAllDay)
      ..writeByte(10)
      ..write(obj.location)
      ..writeByte(11)
      ..write(obj.participantEmailsRaw)
      ..writeByte(12)
      ..write(obj.hasAlarm)
      ..writeByte(13)
      ..write(obj.alarmAt)
      ..writeByte(14)
      ..write(obj.iconKey)
      ..writeByte(15)
      ..write(obj.completion)
      ..writeByte(16)
      ..write(obj.deadline)
      ..writeByte(17)
      ..write(obj.photoPath)
      ..writeByte(18)
      ..write(obj.color)
      ..writeByte(19)
      ..write(obj.topic);
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

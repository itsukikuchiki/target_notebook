// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppUserAdapter extends TypeAdapter<AppUser> {
  @override
  final int typeId = 6;

  @override
  AppUser read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppUser(
      userId: fields[0] as String,
      authProvider: fields[1] as AuthProviderType,
      email: fields[2] as String?,
      displayName: fields[3] as String?,
      isGuest: fields[4] as bool,
      createdAt: fields[5] as DateTime?,
      updatedAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AppUser obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.authProvider)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.displayName)
      ..writeByte(4)
      ..write(obj.isGuest)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AuthProviderTypeAdapter extends TypeAdapter<AuthProviderType> {
  @override
  final int typeId = 7;

  @override
  AuthProviderType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AuthProviderType.guest;
      case 1:
        return AuthProviderType.email;
      case 2:
        return AuthProviderType.google;
      case 3:
        return AuthProviderType.apple;
      case 4:
        return AuthProviderType.line;
      default:
        return AuthProviderType.guest;
    }
  }

  @override
  void write(BinaryWriter writer, AuthProviderType obj) {
    switch (obj) {
      case AuthProviderType.guest:
        writer.writeByte(0);
        break;
      case AuthProviderType.email:
        writer.writeByte(1);
        break;
      case AuthProviderType.google:
        writer.writeByte(2);
        break;
      case AuthProviderType.apple:
        writer.writeByte(3);
        break;
      case AuthProviderType.line:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthProviderTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

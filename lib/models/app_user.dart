import 'package:hive/hive.dart';

part 'app_user.g.dart';

/// W6: 账号来源
@HiveType(typeId: 7)
enum AuthProviderType {
  @HiveField(0)
  guest,

  @HiveField(1)
  email,

  @HiveField(2)
  google,

  @HiveField(3)
  apple,

  @HiveField(4)
  line,
}

/// W6: 本地用户模型（MVP）
@HiveType(typeId: 6)
class AppUser extends HiveObject {
  AppUser({
    required this.userId,
    required this.authProvider,
    this.email,
    this.displayName,
    this.isGuest = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 内部唯一ID（uuid / provider userId）
  @HiveField(0)
  String userId;

  /// 账号来源
  @HiveField(1)
  AuthProviderType authProvider;

  /// 邮箱（guest 可为空；第三方可能为空→需补填）
  @HiveField(2)
  String? email;

  /// 显示名（可为空；首次第三方登录建议补）
  @HiveField(3)
  String? displayName;

  /// 是否访客
  @HiveField(4)
  bool isGuest;

  /// 创建时间
  @HiveField(5)
  DateTime createdAt;

  /// 更新时间
  @HiveField(6)
  DateTime updatedAt;

  /// copyWith：支持显式清空 email/displayName
  AppUser copyWith({
    String? userId,
    AuthProviderType? authProvider,
    Object? email = _unset,
    Object? displayName = _unset,
    bool? isGuest,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      userId: userId ?? this.userId,
      authProvider: authProvider ?? this.authProvider,
      email: email == _unset ? this.email : email as String?,
      displayName:
          displayName == _unset ? this.displayName : displayName as String?,
      isGuest: isGuest ?? this.isGuest,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// 预留：未来接远端（Firestore/Supabase）时直接用
  Map<String, dynamic> toJson() => {
        'userId': userId,
        'authProvider': authProvider.name,
        'email': email,
        'displayName': displayName,
        'isGuest': isGuest,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static AppUser fromJson(Map<String, dynamic> json) {
    AuthProviderType parseProvider(String? v) {
      switch (v) {
        case 'email':
          return AuthProviderType.email;
        case 'google':
          return AuthProviderType.google;
        case 'apple':
          return AuthProviderType.apple;
        case 'line':
          return AuthProviderType.line;
        case 'guest':
        default:
          return AuthProviderType.guest;
      }
    }

    final uid = (json['userId'] ?? '').toString().trim();

    return AppUser(
      userId: uid.isEmpty ? 'unknown' : uid,
      authProvider: parseProvider(json['authProvider']?.toString()),
      email: json['email']?.toString(),
      displayName: json['displayName']?.toString(),
      isGuest: json['isGuest'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}

const Object _unset = Object();


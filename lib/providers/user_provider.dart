// lib/providers/user_provider.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';

import '../core/hive_init.dart';
import '../models/app_user.dart';
import '../models/goal.dart';
import '../models/sub_goal.dart';
import '../models/task.dart';
import '../models/daily_log.dart';

// 🆕 W6: 本地通知（删除账号时取消所有提醒）
import '../services/notification_local_service.dart';

/// W6: 账号/访客 Provider（MVP 本地版）
///
/// 关键点：
/// - Hive 同名 box 必须始终用一致的泛型访问（Box<T>），否则会报
///   "The box xxx is already open and of type Box<...>"。
class UserProvider extends ChangeNotifier {
  static const _kCurrentUserKey = 'current'; // userBox 内固定 key
  static const _kSpLastEmail = 'auth_last_email';
  static const _kSpPwHashPrefix = 'auth_pw_hash_'; // auth_pw_hash_<email>

  final Uuid _uuid = const Uuid();

  late final Box<AppUser> _userBox;
  AppUser? _current;

  /// 🆕 W6: 注入通知 service（删除账号时 cancelAll）
  NotificationLocalService? _notification;

  void bindNotificationService(NotificationLocalService service) {
    _notification = service;
  }

  AppUser? get currentUser => _current;

  bool get hasUser => _current != null;
  bool get isGuest => _current?.isGuest == true;
  bool get isAuthed => _current != null && _current!.isGuest == false;

  /// 对 UI 友好：displayName -> email -> Guest
  String get displayLabel {
    final u = _current;
    if (u == null) return 'Guest';
    final name = (u.displayName ?? '').trim();
    if (name.isNotEmpty) return name;
    final email = (u.email ?? '').trim();
    if (email.isNotEmpty) return email;
    return u.isGuest ? 'Guest' : 'User';
  }

  /// ✅ 初始化：确保 user box 已 open，且一定存在 current user（没有则创建 guest）
  Future<void> init() async {
    _userBox = await _ensureTypedBox<AppUser>(AppBoxes.user);

    final existing = _userBox.get(_kCurrentUserKey);
    if (existing != null) {
      _current = existing;
      return;
    }

    await _createAndSetGuest();
  }

  // ===========================================================
  // 邮箱注册 / 登录（MVP 本地版）
  // ===========================================================

  Future<void> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
    bool keepLocalData = true,
  }) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty) throw ArgumentError('email is empty');
    if (password.isEmpty) throw ArgumentError('password is empty');

    final prefs = await SharedPreferences.getInstance();
    final key = '$_kSpPwHashPrefix$e';

    if (prefs.containsKey(key)) {
      throw StateError('email already registered');
    }

    final hash = _hashPassword(email: e, password: password);
    await prefs.setString(key, hash);
    await prefs.setString(_kSpLastEmail, e);

    await _switchToAuthedUser(
      authProvider: AuthProviderType.email,
      email: e,
      displayName:
          displayName?.trim().isEmpty == true ? null : displayName?.trim(),
      keepLocalData: keepLocalData,
    );
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
    bool keepLocalData = true,
  }) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty) throw ArgumentError('email is empty');
    if (password.isEmpty) throw ArgumentError('password is empty');

    final prefs = await SharedPreferences.getInstance();
    final key = '$_kSpPwHashPrefix$e';
    final saved = prefs.getString(key);

    if (saved == null) {
      throw StateError('email not registered');
    }

    final hash = _hashPassword(email: e, password: password);
    if (hash != saved) {
      throw StateError('invalid password');
    }

    await prefs.setString(_kSpLastEmail, e);

    await _switchToAuthedUser(
      authProvider: AuthProviderType.email,
      email: e,
      keepLocalData: keepLocalData,
    );
  }

  /// 登出：回到 guest（数据保留）
  Future<void> signOutToGuest() async {
    await _createAndSetGuest();
    notifyListeners();
  }

  /// 补资料（给三方登录：无 email / 无用户名的情况）
  Future<void> completeProfile({
    String? email,
    String? displayName,
  }) async {
    final u = _current;
    if (u == null) return;

    final next = u.copyWith(
      email: email?.trim().isEmpty == true ? null : email?.trim().toLowerCase(),
      displayName:
          displayName?.trim().isEmpty == true ? null : displayName?.trim(),
      updatedAt: DateTime.now(),
    );

    await _userBox.put(_kCurrentUserKey, next);
    _current = next;
    notifyListeners();
  }

  // ===========================================================
  // 三方登录（接口占位）
  // ===========================================================

  Future<void> signInWithGoogle({
    required String userId,
    String? email,
    String? displayName,
    bool keepLocalData = true,
  }) async {
    await _switchToAuthedUser(
      forcedUserId: userId,
      authProvider: AuthProviderType.google,
      email: email,
      displayName: displayName,
      keepLocalData: keepLocalData,
    );
  }

  Future<void> signInWithApple({
    required String userId,
    String? email,
    String? displayName,
    bool keepLocalData = true,
  }) async {
    await _switchToAuthedUser(
      forcedUserId: userId,
      authProvider: AuthProviderType.apple,
      email: email,
      displayName: displayName,
      keepLocalData: keepLocalData,
    );
  }

  Future<void> signInWithLine({
    required String userId,
    String? email,
    String? displayName,
    bool keepLocalData = true,
  }) async {
    await _switchToAuthedUser(
      forcedUserId: userId,
      authProvider: AuthProviderType.line,
      email: email,
      displayName: displayName,
      keepLocalData: keepLocalData,
    );
  }

  // ===========================================================
  // 删除账号 & 数据
  // ===========================================================

  Future<void> deleteAccountAndData() async {
    await wipeLocalData();
    notifyListeners();
  }

  /// 清空本地全部业务数据 + 清理登录凭据 + 重建 guest
  Future<void> wipeLocalData() async {
    await _notification?.cancelAll();

    // ✅ 业务数据：同名 box 必须用一致的泛型访问
    await (await _ensureTypedBox<Goal>(AppBoxes.goal)).clear();
    await (await _ensureTypedBox<SubGoal>(AppBoxes.subGoal)).clear();
    await (await _ensureTypedBox<Task>(AppBoxes.task)).clear();
    await (await _ensureTypedBox<DailyLog>(AppBoxes.dailyLog)).clear();

    // ✅ user box
    await _userBox.clear();

    // 清理 SharedPreferences 的邮箱密码 hash
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();
    for (final k in keys) {
      if (k.startsWith(_kSpPwHashPrefix) || k == _kSpLastEmail) {
        await prefs.remove(k);
      }
    }

    // ✅ wipe 后立刻重建 guest
    await _createAndSetGuest();
  }

  // ===========================================================
  // internal helpers
  // ===========================================================

  /// ✅ 确保用 typed box 打开，避免 Hive “already open and of type Box<T>” 崩溃
  Future<Box<T>> _ensureTypedBox<T>(String name) async {
    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }
    return Hive.openBox<T>(name);
  }

  Future<void> _createAndSetGuest() async {
    final guest = AppUser(
      userId: _uuid.v4(),
      authProvider: AuthProviderType.guest,
      isGuest: true,
      displayName: 'Guest',
      updatedAt: DateTime.now(),
    );

    await _userBox.put(_kCurrentUserKey, guest);
    _current = guest;
  }

  String _hashPassword({required String email, required String password}) {
    // MVP：sha256(email + ':' + password)
    final bytes = utf8.encode('$email:$password');
    return sha256.convert(bytes).toString();
  }

  Future<void> _switchToAuthedUser({
    String? forcedUserId,
    required AuthProviderType authProvider,
    String? email,
    String? displayName,
    required bool keepLocalData,
  }) async {
    if (!keepLocalData) {
      await (await _ensureTypedBox<Goal>(AppBoxes.goal)).clear();
      await (await _ensureTypedBox<SubGoal>(AppBoxes.subGoal)).clear();
      await (await _ensureTypedBox<Task>(AppBoxes.task)).clear();
      await (await _ensureTypedBox<DailyLog>(AppBoxes.dailyLog)).clear();
      await _notification?.cancelAll();
    }

    final next = AppUser(
      userId: forcedUserId ?? _uuid.v4(),
      authProvider: authProvider,
      email: email?.trim().isEmpty == true ? null : email?.trim().toLowerCase(),
      displayName:
          displayName?.trim().isEmpty == true ? null : displayName?.trim(),
      isGuest: false,
      updatedAt: DateTime.now(),
    );

    await _userBox.put(_kCurrentUserKey, next);
    _current = next;
    notifyListeners();
  }
}


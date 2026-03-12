// lib/providers/user_provider.dart
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/hive_init.dart';
import '../models/app_user.dart';
import '../models/daily_log.dart';
import '../models/goal.dart';
import '../models/sub_goal.dart';
import '../models/task.dart';
import '../services/notification_service.dart';

class UserProvider extends ChangeNotifier {
  static const String _kCurrentUserKey = 'current';
  static const String _kSpLastEmail = 'auth_last_email';
  static const String _kSpPwHashPrefix = 'auth_pw_hash_';
  static const String _kSpResetAtPrefix = 'auth_reset_at_';

  final Uuid _uuid = const Uuid();

  late final Box<AppUser> _userBox;
  AppUser? _current;

  NotificationService? _notification;

  void bindNotificationService(NotificationService service) {
    _notification = service;
  }

  AppUser? get currentUser => _current;

  bool get hasUser => _current != null;
  bool get isGuest => _current?.isGuest == true;
  bool get isAuthed => _current != null && _current!.isGuest == false;

  String get displayLabel {
    final u = _current;
    if (u == null) return 'Guest';

    final name = (u.displayName ?? '').trim();
    if (name.isNotEmpty) return name;

    final email = (u.email ?? '').trim();
    if (email.isNotEmpty) return email;

    return u.isGuest ? 'Guest' : 'User';
  }

  Future<void> init() async {
    _userBox = await _ensureTypedBox<AppUser>(AppBoxes.user);

    final existing = _userBox.get(_kCurrentUserKey);
    if (existing != null) {
      _current = existing;
      return;
    }

    await _createAndSetGuest();
  }

  Future<void> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
    bool keepLocalData = true,
  }) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty) {
      throw ArgumentError('email is empty');
    }
    if (password.isEmpty) {
      throw ArgumentError('password is empty');
    }

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
    if (e.isEmpty) {
      throw ArgumentError('email is empty');
    }
    if (password.isEmpty) {
      throw ArgumentError('password is empty');
    }

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

  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty) {
      throw ArgumentError('email is empty');
    }
    if (newPassword.isEmpty) {
      throw ArgumentError('password is empty');
    }

    final prefs = await SharedPreferences.getInstance();
    final key = '$_kSpPwHashPrefix$e';
    final saved = prefs.getString(key);

    if (saved == null) {
      throw StateError('email not registered');
    }

    final hash = _hashPassword(email: e, password: newPassword);
    await prefs.setString(key, hash);
    await prefs.setInt(
      '$_kSpResetAtPrefix$e',
      DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setString(_kSpLastEmail, e);
  }

  Future<void> signOutToGuest() async {
    await _createAndSetGuest();
    notifyListeners();
  }

  Future<void> completeProfile({
    String? email,
    String? displayName,
  }) async {
    final u = _current;
    if (u == null) return;

    final normalizedEmail = email?.trim().toLowerCase();
    final normalizedName = displayName?.trim();

    final next = u.copyWith(
      email: (normalizedEmail == null || normalizedEmail.isEmpty)
          ? null
          : normalizedEmail,
      displayName:
          (normalizedName == null || normalizedName.isEmpty) ? null : normalizedName,
      updatedAt: DateTime.now(),
    );

    await _userBox.put(_kCurrentUserKey, next);
    _current = next;
    notifyListeners();
  }

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

  Future<void> deleteAccountAndData() async {
    await wipeLocalData();
    notifyListeners();
  }

  Future<void> wipeLocalData() async {
    await _notification?.cancelAll();

    await (await _ensureTypedBox<Goal>(AppBoxes.goal)).clear();
    await (await _ensureTypedBox<SubGoal>(AppBoxes.subGoal)).clear();
    await (await _ensureTypedBox<Task>(AppBoxes.task)).clear();
    await (await _ensureTypedBox<DailyLog>(AppBoxes.dailyLog)).clear();

    await _userBox.clear();

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();

    for (final k in keys) {
      if (k.startsWith(_kSpPwHashPrefix) ||
          k.startsWith(_kSpResetAtPrefix) ||
          k == _kSpLastEmail) {
        await prefs.remove(k);
      }
    }

    await _createAndSetGuest();
  }

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

  String _hashPassword({
    required String email,
    required String password,
  }) {
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

    final normalizedEmail = email?.trim().toLowerCase();
    final normalizedName = displayName?.trim();

    final next = AppUser(
      userId: forcedUserId ?? _uuid.v4(),
      authProvider: authProvider,
      email: (normalizedEmail == null || normalizedEmail.isEmpty)
          ? null
          : normalizedEmail,
      displayName:
          (normalizedName == null || normalizedName.isEmpty) ? null : normalizedName,
      isGuest: false,
      updatedAt: DateTime.now(),
    );

    await _userBox.put(_kCurrentUserKey, next);
    _current = next;
    notifyListeners();
  }
}

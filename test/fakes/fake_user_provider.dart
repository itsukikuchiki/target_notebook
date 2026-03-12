import 'package:flutter/foundation.dart';

import 'package:target_notebook/models/app_user.dart';
import 'package:target_notebook/providers/user_provider.dart';
import 'package:target_notebook/services/notification_service.dart';

class FakeUserProvider extends ChangeNotifier implements UserProvider {
  AppUser? _current = AppUser(
    userId: 'guest',
    authProvider: AuthProviderType.guest,
    isGuest: true,
    displayName: 'Guest',
    updatedAt: DateTime(2026, 1, 1),
  );

  // 可用于断言
  bool deleteCalled = false;
  bool signOutCalled = false;
  bool wipeLocalCalled = false;

  bool resetPwCalled = false;
  String? _lastResetEmail;

  /// ✅ 兼容 test/widget/me_page_settings_and_reset_test.dart 里的断言
  bool get resetPasswordCalled => resetPwCalled;

  /// ✅ 兼容 test/widget/me_page_settings_and_reset_test.dart 里的断言
  String? get lastResetEmail => _lastResetEmail;

  NotificationService? boundNotification;

  @override
  AppUser? get currentUser => _current;

  @override
  bool get hasUser => _current != null;

  @override
  bool get isGuest => _current?.isGuest == true;

  @override
  bool get isAuthed => _current != null && _current!.isGuest == false;

  @override
  String get displayLabel {
    final u = _current;
    if (u == null) return 'Guest';
    final name = (u.displayName ?? '').trim();
    if (name.isNotEmpty) return name;
    final email = (u.email ?? '').trim();
    if (email.isNotEmpty) return email;
    return u.isGuest ? 'Guest' : 'User';
  }

  @override
  Future<void> init() async {
    // 测试用：no-op（保持已有 _current）
  }

  @override
  void bindNotificationService(NotificationService service) {
    boundNotification = service;
  }

  @override
  Future<void> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
    bool keepLocalData = true,
  }) async {
    _current = AppUser(
      userId: 'email_user',
      authProvider: AuthProviderType.email,
      email: email.trim().toLowerCase(),
      displayName: (displayName ?? '').trim().isEmpty ? null : displayName!.trim(),
      isGuest: false,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
    bool keepLocalData = true,
  }) async {
    _current = AppUser(
      userId: 'email_user',
      authProvider: AuthProviderType.email,
      email: email.trim().toLowerCase(),
      displayName: 'User',
      isGuest: false,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    resetPwCalled = true;
    _lastResetEmail = email.trim().toLowerCase();
    // fake: just accept
  }

  @override
  Future<void> signOutToGuest() async {
    signOutCalled = true;
    _current = AppUser(
      userId: 'guest',
      authProvider: AuthProviderType.guest,
      isGuest: true,
      displayName: 'Guest',
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  Future<void> wipeLocalData() async {
    wipeLocalCalled = true;
    _current = AppUser(
      userId: 'guest',
      authProvider: AuthProviderType.guest,
      isGuest: true,
      displayName: 'Guest',
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  Future<void> deleteAccountAndData() async {
    deleteCalled = true;
    await wipeLocalData();
    notifyListeners();
  }

  @override
  Future<void> completeProfile({
    String? email,
    String? displayName,
  }) async {
    final u = _current;
    if (u == null) return;

    _current = u.copyWith(
      email: (email ?? '').trim().isEmpty ? null : email!.trim().toLowerCase(),
      displayName: (displayName ?? '').trim().isEmpty ? null : displayName!.trim(),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  Future<void> signInWithGoogle({
    required String userId,
    String? email,
    String? displayName,
    bool keepLocalData = true,
  }) async {
    _current = AppUser(
      userId: userId,
      authProvider: AuthProviderType.google,
      email: (email ?? '').trim().isEmpty ? null : email!.trim().toLowerCase(),
      displayName: (displayName ?? '').trim().isEmpty ? null : displayName!.trim(),
      isGuest: false,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  Future<void> signInWithApple({
    required String userId,
    String? email,
    String? displayName,
    bool keepLocalData = true,
  }) async {
    _current = AppUser(
      userId: userId,
      authProvider: AuthProviderType.apple,
      email: (email ?? '').trim().isEmpty ? null : email!.trim().toLowerCase(),
      displayName: (displayName ?? '').trim().isEmpty ? null : displayName!.trim(),
      isGuest: false,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  Future<void> signInWithLine({
    required String userId,
    String? email,
    String? displayName,
    bool keepLocalData = true,
  }) async {
    _current = AppUser(
      userId: userId,
      authProvider: AuthProviderType.line,
      email: (email ?? '').trim().isEmpty ? null : email!.trim().toLowerCase(),
      displayName: (displayName ?? '').trim().isEmpty ? null : displayName!.trim(),
      isGuest: false,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }
}

// test/widget/me_page_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:target_notebook/models/app_user.dart';
import 'package:target_notebook/pages/me_page.dart';
import 'package:target_notebook/pages/legal_page.dart';
import 'package:target_notebook/providers/user_provider.dart';
import 'package:target_notebook/providers/settings_provider.dart';
import 'package:target_notebook/services/notification_local_service.dart';
import 'package:target_notebook/services/notification_service.dart';

import '../fakes/fake_notification_local_service.dart';

class _TestAssetBundle extends CachingAssetBundle {
  final Map<String, String> data;
  _TestAssetBundle(this.data);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final v = data[key];
    if (v == null) throw FlutterError('Asset not found: $key');
    return v;
  }

  @override
  Future<ByteData> load(String key) async {
    final v = data[key];
    if (v == null) throw FlutterError('Asset not found: $key');
    final bytes = Uint8List.fromList(v.codeUnits);
    return ByteData.view(bytes.buffer);
  }
}

class _FakeUserProvider extends ChangeNotifier implements UserProvider {
  AppUser? _current = AppUser(
    userId: 'guest',
    authProvider: AuthProviderType.guest,
    isGuest: true,
    displayName: 'Guest',
    updatedAt: DateTime(2026, 1, 1),
  );

  bool deleteCalled = false;
  bool signOutCalled = false;
  bool wipeLocalCalled = false;

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
  Future<void> init() async {}

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

  // ✅ 新增接口：补齐 resetPassword，避免编译失败
  @override
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    // no-op
  }

  // ✅ 兜底：未来接口新增也不会再编译炸
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSettingsProvider extends ChangeNotifier implements SettingsProvider {
  bool clearedAvatar = false;

  WeekStart _weekStart = WeekStart.monday;
  SoundId _soundId = SoundId.none;

  @override
  bool get inited => true;

  @override
  WeekStart get weekStart => _weekStart;

  @override
  SoundId get soundId => _soundId;

  @override
  String? get avatarPath => null;

  @override
  File? get avatarFile => null;

  @override
  bool get seenOnboarding => true;

  @override
  Future<void> init() async {}

  @override
  Future<void> setWeekStart(WeekStart v) async {
    _weekStart = v;
    notifyListeners();
  }

  @override
  Future<void> setSoundId(SoundId v) async {
    _soundId = v;
    notifyListeners();
  }

  @override
  Future<void> setAvatarPath(String? path) async {}

  @override
  Future<void> clearAvatar() async {
    clearedAvatar = true;
    notifyListeners();
  }

  @override
  Future<void> setSeenOnboarding(bool v) async {}
}

Finder _firstExistingTextFinder(List<String> candidates) {
  for (final s in candidates) {
    final f = find.text(s);
    if (f.evaluate().isNotEmpty) return f;
  }
  return find.textContaining('删除');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MePage guest: can open email auth dialog and toggle login/register', (tester) async {
    final userP = _FakeUserProvider();
    final settingsP = _FakeSettingsProvider();
    final notif = FakeNotificationLocalService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: userP),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsP),
          Provider<NotificationLocalService>.value(value: notif),
        ],
        child: const MaterialApp(home: Scaffold(body: MePage())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('登录 / 注册（邮箱）'), findsOneWidget);

    await tester.tap(find.text('登录 / 注册（邮箱）'));
    await tester.pumpAndSettle();

    expect(find.text('邮箱登录'), findsOneWidget);
    expect(find.text('没有账号？去注册'), findsOneWidget);

    await tester.tap(find.text('没有账号？去注册'));
    await tester.pumpAndSettle();

    expect(find.text('邮箱注册'), findsOneWidget);
    expect(find.text('已有账号？去登录'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('邮箱登录'), findsNothing);
  });

  testWidgets('MePage can change sound/weekStart and delete data flow calls services', (tester) async {
    final userP = _FakeUserProvider();
    final settingsP = _FakeSettingsProvider();
    final notif = FakeNotificationLocalService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: userP),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsP),
          Provider<NotificationLocalService>.value(value: notif),
        ],
        child: const MaterialApp(home: Scaffold(body: MePage())),
      ),
    );

    await tester.pumpAndSettle();

    // Sound picker
    await tester.tap(find.text('提示音'));
    await tester.pumpAndSettle();
    expect(find.text('选择提示音'), findsOneWidget);

    await tester.tap(find.textContaining('Bell'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(settingsP.soundId, SoundId.bell);

    // Week start picker
    await tester.tap(find.text('周开始日'));
    await tester.pumpAndSettle();
    expect(find.text('周开始日'), findsWidgets);

    await tester.tap(find.text('周日开始'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(settingsP.weekStart, WeekStart.sunday);

    // Delete flow: scroll down then tap delete entry (copy changes tolerate text)
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.fling(scrollable.first, const Offset(0, -1200), 1000);
      await tester.pumpAndSettle();
      await tester.fling(scrollable.first, const Offset(0, -1200), 1000);
      await tester.pumpAndSettle();
    }

    final deleteEntry = _firstExistingTextFinder([
      '删除账号 & 本地数据',
      '删除账号与本地数据',
      '删除账号',
      '删除本地数据',
      '删除数据',
    ]);

    expect(deleteEntry, findsWidgets);
    await tester.ensureVisible(deleteEntry.first);
    await tester.pumpAndSettle();
    await tester.tap(deleteEntry.first);
    await tester.pumpAndSettle();

    expect(find.text('确认删除？'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(notif.cancelAllCalled, true);
    expect(settingsP.clearedAvatar, true);
    expect(userP.deleteCalled, true);

    expect(find.text('数据已删除'), findsOneWidget);
  });

  testWidgets('MePage legal cards navigate to LegalPage', (tester) async {
    final userP = _FakeUserProvider();
    final settingsP = _FakeSettingsProvider();
    final notif = FakeNotificationLocalService();

    final bundle = _TestAssetBundle({
      'assets/legal/privacy_zh.txt': 'PRIVACY ZH',
      'assets/legal/terms_zh.txt': 'TERMS ZH',
    });

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: bundle,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<UserProvider>.value(value: userP),
            ChangeNotifierProvider<SettingsProvider>.value(value: settingsP),
            Provider<NotificationLocalService>.value(value: notif),
          ],
          child: const MaterialApp(home: Scaffold(body: MePage())),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('隐私政策'));
    await tester.pumpAndSettle();

    expect(find.byType(LegalPage), findsOneWidget);
    expect(find.text('PRIVACY ZH'), findsOneWidget);
  });
}

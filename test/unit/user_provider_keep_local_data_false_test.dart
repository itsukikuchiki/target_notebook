// test/unit/user_provider_keep_local_data_false_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/app_user.dart';
import 'package:target_notebook/models/daily_log.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/sub_goal.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/providers/user_provider.dart';
import 'package:target_notebook/services/notification_service.dart';

import '../helpers/hive_test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await clearHiveBoxes();
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  Future<void> _seedBusinessData() async {
    await Hive.box<Goal>(AppBoxes.goal).add(Goal(title: 'G', priority: 1, color: 0xFF112233));
    await Hive.box<SubGoal>(AppBoxes.subGoal).add(SubGoal(goalId: 1, title: 'SG', priority: 1));
    await Hive.box<Task>(AppBoxes.task).add(Task(title: 'T', startAt: DateTime(2026, 1, 1)));
    await Hive.box<DailyLog>(AppBoxes.dailyLog).add(
      DailyLog(date: DateTime(2026, 1, 1), content: 'L', minutes: 15),
    );
  }

  void _expectCleared() {
    expect(Hive.box<Goal>(AppBoxes.goal).isEmpty, true);
    expect(Hive.box<SubGoal>(AppBoxes.subGoal).isEmpty, true);
    expect(Hive.box<Task>(AppBoxes.task).isEmpty, true);
    expect(Hive.box<DailyLog>(AppBoxes.dailyLog).isEmpty, true);
  }

  test('UserProvider signIn keepLocalData=false (LINE) clears business boxes + cancels notifications',
      () async {
    final notif = _FakeNotif();
    final user = UserProvider();
    await user.init();
    user.bindNotificationService(notif);

    await _seedBusinessData();
    expect(Hive.box<Goal>(AppBoxes.goal).isNotEmpty, true);

    await user.signInWithLine(
      userId: 'line_1',
      email: null,
      displayName: null,
      keepLocalData: false,
    );

    expect(notif.cancelAllCalls, 1);
    _expectCleared();

    expect(user.isAuthed, true);
    expect(user.currentUser?.authProvider, AuthProviderType.line);
    expect(user.currentUser?.isGuest, false);
  });

  test('UserProvider signIn keepLocalData=false (Google) clears business boxes + cancels notifications',
      () async {
    final notif = _FakeNotif();
    final user = UserProvider();
    await user.init();
    user.bindNotificationService(notif);

    await _seedBusinessData();

    await user.signInWithGoogle(
      userId: 'google_1',
      email: null,
      displayName: null,
      keepLocalData: false,
    );

    expect(notif.cancelAllCalls, 1);
    _expectCleared();

    expect(user.isAuthed, true);
    expect(user.currentUser?.authProvider, AuthProviderType.google);
    expect(user.currentUser?.isGuest, false);
  });

  test('UserProvider signIn keepLocalData=false (Apple) clears business boxes + cancels notifications',
      () async {
    final notif = _FakeNotif();
    final user = UserProvider();
    await user.init();
    user.bindNotificationService(notif);

    await _seedBusinessData();

    await user.signInWithApple(
      userId: 'apple_1',
      email: null,
      displayName: null,
      keepLocalData: false,
    );

    expect(notif.cancelAllCalls, 1);
    _expectCleared();

    expect(user.isAuthed, true);
    expect(user.currentUser?.authProvider, AuthProviderType.apple);
    expect(user.currentUser?.isGuest, false);
  });
}

class _FakeNotif implements NotificationService {
  int cancelAllCalls = 0;

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
  }

  // ✅ 新接口补齐：用 noSuchMethod 吃掉剩余成员，避免每次接口扩展都炸测试
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

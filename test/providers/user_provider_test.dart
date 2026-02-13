import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/models/daily_log.dart';
import 'package:target_notebook/models/sub_goal.dart';
import 'package:target_notebook/models/app_user.dart';
import 'package:target_notebook/providers/user_provider.dart';

import '../helpers/hive_test_env.dart';

void main() {
  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // 清空所有 box，避免串测试（注意：必须与 open 时的 Box<T> 类型一致）
    await Hive.box<Goal>(AppBoxes.goal).clear();
    await Hive.box<SubGoal>(AppBoxes.subGoal).clear();
    await Hive.box<Task>(AppBoxes.task).clear();
    await Hive.box<DailyLog>(AppBoxes.dailyLog).clear();
    await Hive.box<AppUser>(AppBoxes.user).clear();
  });

  test('UserProvider.init creates guest when no current user', () async {
    final p = UserProvider();
    await p.init();

    expect(p.hasUser, true);
    expect(p.isGuest, true);
    expect(p.displayLabel, 'Guest');

    final userBox = Hive.box<AppUser>(AppBoxes.user);
    expect(userBox.isNotEmpty, true);
  });

  test('registerWithEmail -> authed user and stores password hash in SharedPreferences', () async {
    final p = UserProvider();
    await p.init();

    await p.registerWithEmail(email: 'A@EXAMPLE.com', password: '123456');

    expect(p.isAuthed, true);
    expect(p.isGuest, false);
    expect(p.currentUser?.email, 'a@example.com');

    final sp = await SharedPreferences.getInstance();
    expect(sp.getString('auth_last_email'), 'a@example.com');

    // hash 存在
    expect(sp.getString('auth_pw_hash_a@example.com')?.isNotEmpty, true);
  });

  test('signInWithEmail validates password and switches current user', () async {
    final p = UserProvider();
    await p.init();

    await p.registerWithEmail(email: 't@t.com', password: 'pw');
    await p.signOutToGuest();

    expect(p.isGuest, true);

    await p.signInWithEmail(email: 't@t.com', password: 'pw');
    expect(p.isAuthed, true);
    expect(p.currentUser?.email, 't@t.com');
  });

  test('deleteAccountAndData wipes business boxes + auth keys and returns to guest', () async {
    // 先写点业务数据
    final goalBox = Hive.box<Goal>(AppBoxes.goal);
    final taskBox = Hive.box<Task>(AppBoxes.task);
    final logBox = Hive.box<DailyLog>(AppBoxes.dailyLog);

    await goalBox.add(Goal(title: 'g', description: 'd', priority: 1, color: 0xFF000000));
    await taskBox.add(Task(title: 't'));
    await logBox.add(DailyLog(date: DateTime.now(), content: 'c', minutes: 10));

    final p = UserProvider();
    await p.init();
    await p.registerWithEmail(email: 'x@x.com', password: 'pw');

    // 再删
    await p.deleteAccountAndData();

    expect(p.isGuest, true);
    expect(goalBox.isEmpty, true);
    expect(taskBox.isEmpty, true);
    expect(logBox.isEmpty, true);

    final sp = await SharedPreferences.getInstance();
    expect(sp.getString('auth_pw_hash_x@x.com'), null);
    expect(sp.getString('auth_last_email'), null);
  });
}


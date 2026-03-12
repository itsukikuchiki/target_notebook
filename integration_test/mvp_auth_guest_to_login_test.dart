// integration_test/mvp_auth_guest_to_login_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/providers/user_provider.dart';
import 'package:target_notebook/services/notification_local_service.dart';

import '../test/helpers/hive_test_env.dart';
import '../test/fakes/fake_notification_local_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('guest -> register -> data kept -> wipe -> guest & cleared', (tester) async {
    final user = UserProvider();
    await user.init();

    final notif = FakeNotificationLocalService();
    user.bindNotificationService(notif);

    // seed local data (simulate guest created goal)
    await Hive.box<Goal>(AppBoxes.goal).add(
      Goal(title: 'G', priority: 1, color: 0xFF000000),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: user),
          Provider<NotificationLocalService>.value(value: notif),
        ],
        child: const MaterialApp(
          home: _AuthHarness(),
        ),
      ),
    );

    // 初始 guest
    expect(find.textContaining('guest:'), findsOneWidget);

    // register
    await tester.tap(find.byKey(const Key('btn_register')));
    await tester.pumpAndSettle();

    expect(find.textContaining('authed:'), findsOneWidget);
    // keepLocalData default true -> goalBox should still have 1
    expect(Hive.box<Goal>(AppBoxes.goal).length, 1);

    // wipe
    await tester.tap(find.byKey(const Key('btn_wipe')));
    await tester.pumpAndSettle();

    expect(notif.cancelAllCalls, 1);
    expect(Hive.box<Goal>(AppBoxes.goal).isEmpty, true);
    expect(find.textContaining('guest:'), findsOneWidget);
  });

  testWidgets('third-party sign-in (no email/name) -> needs profile -> completeProfile persists', (tester) async {
    final user = UserProvider();
    await user.init();

    final notif = FakeNotificationLocalService();
    user.bindNotificationService(notif);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: user),
          Provider<NotificationLocalService>.value(value: notif),
        ],
        child: const MaterialApp(
          home: _ThirdPartyProfileHarness(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 初始 guest
    expect(find.textContaining('guest:'), findsOneWidget);
    expect(find.textContaining('needsProfile:false'), findsOneWidget);

    // google sign-in without email/displayName
    await tester.tap(find.byKey(const Key('btn_google_no_profile')));
    await tester.pumpAndSettle();

    expect(find.textContaining('authed:'), findsOneWidget);
    expect(find.textContaining('needsProfile:true'), findsOneWidget);

    // complete profile
    await tester.tap(find.byKey(const Key('btn_complete_profile')));
    await tester.pumpAndSettle();

    // now should be authed, and label should become displayName (优先于 email)
    expect(find.textContaining('authed:Yang'), findsOneWidget);
    expect(find.textContaining('needsProfile:false'), findsOneWidget);

    // reboot simulation: rebuild provider from Hive
    final user2 = UserProvider();
    await user2.init();

    expect(user2.isAuthed, true);
    expect(user2.displayLabel, 'Yang');
    expect((user2.currentUser?.email ?? ''), 'yy@test.com');
  });
}

class _AuthHarness extends StatelessWidget {
  const _AuthHarness();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final label = user.isAuthed ? 'authed:${user.displayLabel}' : 'guest:${user.displayLabel}';

    return Scaffold(
      appBar: AppBar(title: const Text('AuthHarness')),
      body: Column(
        children: [
          Text(label),
          const SizedBox(height: 12),
          ElevatedButton(
            key: const Key('btn_register'),
            onPressed: () async {
              await context.read<UserProvider>().registerWithEmail(
                    email: 't@test.com',
                    password: 'pw',
                    displayName: 'T',
                  );
            },
            child: const Text('Register'),
          ),
          ElevatedButton(
            key: const Key('btn_wipe'),
            onPressed: () async {
              await context.read<UserProvider>().wipeLocalData();
            },
            child: const Text('Wipe'),
          ),
        ],
      ),
    );
  }
}

class _ThirdPartyProfileHarness extends StatelessWidget {
  const _ThirdPartyProfileHarness();

  bool _needsProfile(UserProvider u) {
    if (!u.isAuthed) return false;
    final email = (u.currentUser?.email ?? '').trim();
    final name = (u.currentUser?.displayName ?? '').trim();
    return email.isEmpty || name.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final label = user.isAuthed ? 'authed:${user.displayLabel}' : 'guest:${user.displayLabel}';
    final needs = _needsProfile(user);

    return Scaffold(
      appBar: AppBar(title: const Text('ThirdPartyProfileHarness')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Text('needsProfile:$needs'),
          const SizedBox(height: 12),
          ElevatedButton(
            key: const Key('btn_google_no_profile'),
            onPressed: () async {
              await context.read<UserProvider>().signInWithGoogle(
                    userId: 'google_1',
                    email: null,
                    displayName: null,
                    keepLocalData: true,
                  );
            },
            child: const Text('Google SignIn (no profile)'),
          ),
          ElevatedButton(
            key: const Key('btn_complete_profile'),
            onPressed: needs
                ? () async {
                    await context.read<UserProvider>().completeProfile(
                          email: 'yy@test.com',
                          displayName: 'Yang',
                        );
                  }
                : null,
            child: const Text('Complete Profile'),
          ),
        ],
      ),
    );
  }
}

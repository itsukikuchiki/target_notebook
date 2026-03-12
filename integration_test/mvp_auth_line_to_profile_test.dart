import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets(
    'LINE sign-in (no email/name) -> needs profile -> completeProfile persists (reboot)',
    (tester) async {
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
          child: const MaterialApp(home: _LineProfileHarness()),
        ),
      );
      await tester.pumpAndSettle();

      // initial guest
      expect(find.textContaining('guest:'), findsOneWidget);
      expect(find.textContaining('needsProfile:false'), findsOneWidget);

      // LINE sign-in without email/displayName
      await tester.tap(find.byKey(const Key('btn_line_no_profile')));
      await tester.pumpAndSettle();

      expect(find.textContaining('authed:'), findsOneWidget);
      expect(find.textContaining('provider:line'), findsOneWidget);
      expect(find.textContaining('needsProfile:true'), findsOneWidget);

      // complete profile
      await tester.tap(find.byKey(const Key('btn_complete_profile')));
      await tester.pumpAndSettle();

      expect(find.textContaining('authed:Yang'), findsOneWidget);
      expect(find.textContaining('needsProfile:false'), findsOneWidget);

      // reboot simulation
      final user2 = UserProvider();
      await user2.init();

      expect(user2.isAuthed, true);
      expect(user2.currentUser?.authProvider.name, 'line');
      expect(user2.displayLabel, 'Yang');
      expect(user2.currentUser?.email, 'yy@test.com');
    },
  );

  testWidgets(
    'LINE sign-in (with email/name) -> needsProfile false -> persists (reboot)',
    (tester) async {
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
          child: const MaterialApp(home: _LineProfileHarness()),
        ),
      );
      await tester.pumpAndSettle();

      // initial guest
      expect(find.textContaining('guest:'), findsOneWidget);

      // LINE sign-in with email/displayName
      await tester.tap(find.byKey(const Key('btn_line_with_profile')));
      await tester.pumpAndSettle();

      expect(find.textContaining('authed:LineUser'), findsOneWidget);
      expect(find.textContaining('provider:line'), findsOneWidget);
      expect(find.textContaining('needsProfile:false'), findsOneWidget);

      // reboot simulation
      final user2 = UserProvider();
      await user2.init();

      expect(user2.isAuthed, true);
      expect(user2.currentUser?.authProvider.name, 'line');
      expect(user2.displayLabel, 'LineUser');
      expect(user2.currentUser?.email, 'line@test.com');
    },
  );
}

class _LineProfileHarness extends StatelessWidget {
  const _LineProfileHarness();

  bool _needsProfile(UserProvider u) {
    if (!u.isAuthed) return false;
    final email = (u.currentUser?.email ?? '').trim();
    final name = (u.currentUser?.displayName ?? '').trim();
    return email.isEmpty || name.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final label =
        user.isAuthed ? 'authed:${user.displayLabel}' : 'guest:${user.displayLabel}';

    final needs = _needsProfile(user);
    final provider = user.currentUser?.authProvider.name ?? 'none';

    return Scaffold(
      appBar: AppBar(title: const Text('LineProfileHarness')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Text('provider:$provider'),
          Text('needsProfile:$needs'),
          const SizedBox(height: 12),
          ElevatedButton(
            key: const Key('btn_line_no_profile'),
            onPressed: () async {
              await context.read<UserProvider>().signInWithLine(
                    userId: 'line_1',
                    email: null,
                    displayName: null,
                    keepLocalData: true,
                  );
            },
            child: const Text('LINE SignIn (no profile)'),
          ),
          ElevatedButton(
            key: const Key('btn_line_with_profile'),
            onPressed: () async {
              await context.read<UserProvider>().signInWithLine(
                    userId: 'line_2',
                    email: 'line@test.com',
                    displayName: 'LineUser',
                    keepLocalData: true,
                  );
            },
            child: const Text('LINE SignIn (with profile)'),
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

// test/widget/splash_navigation_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:target_notebook/pages/splash_page.dart';
import 'package:target_notebook/pages/onboarding_page.dart';
import 'package:target_notebook/providers/user_provider.dart';
import 'package:target_notebook/providers/settings_provider.dart';
import 'package:target_notebook/services/notification_local_service.dart';

import '../fakes/fake_user_provider.dart';
import '../fakes/fake_settings_provider.dart';
import '../fakes/always_ready_notification_local_service.dart';

void main() {
  testWidgets('Splash navigates to /home when seenOnboarding=true', (tester) async {
    final user = FakeUserProvider();
    final settings = FakeSettingsProvider(seenOnboarding: true);
    final notif = AlwaysReadyNotificationLocalService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: user),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          Provider<NotificationLocalService>.value(value: notif),
        ],
        child: MaterialApp(
          home: const SplashPage(
            preDelay: Duration.zero,
            postDelay: Duration.zero,
          ),
          routes: {
            '/home': (_) => const Scaffold(body: Text('HOME')),
            OnboardingPage.route: (_) => const Scaffold(body: Text('ONBOARDING')),
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(notif.isReady, true);
  });

  testWidgets('Splash navigates to onboarding when seenOnboarding=false', (tester) async {
    final user = FakeUserProvider();
    final settings = FakeSettingsProvider(seenOnboarding: false);
    final notif = AlwaysReadyNotificationLocalService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: user),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          Provider<NotificationLocalService>.value(value: notif),
        ],
        child: MaterialApp(
          home: const SplashPage(
            preDelay: Duration.zero,
            postDelay: Duration.zero,
          ),
          routes: {
            '/home': (_) => const Scaffold(body: Text('HOME')),
            OnboardingPage.route: (_) => const Scaffold(body: Text('ONBOARDING')),
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ONBOARDING'), findsOneWidget);
  });
}


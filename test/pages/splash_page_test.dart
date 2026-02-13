// test/pages/splash_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:target_notebook/pages/splash_page.dart';
import 'package:target_notebook/providers/user_provider.dart';
import 'package:target_notebook/services/notification_local_service.dart';

class FakeNotificationLocalService extends NotificationLocalService {
  bool ensured = false;

  @override
  Future<void> init() async {}

  @override
  Future<void> ensureReady() async {
    ensured = true;
  }
}

class _TestNavObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = <Route<dynamic>>[];
  final List<Route<dynamic>> replacedNew = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) replacedNew.add(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  int maxSteps = 200, // 200 * 50ms = 10s 上限（足够覆盖 Splash 延迟/动画）
}) async {
  for (int i = 0; i < maxSteps; i++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  // 最后再补一帧，便于失败时稳定复现
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SplashPage boots and navigates to /home', (tester) async {
    final userP = UserProvider();
    final notification = FakeNotificationLocalService();
    final navObserver = _TestNavObserver();

    // ✅ 如果 init 里有平台/IO（SharedPreferences / path_provider 等），用 runAsync 更稳
    await tester.runAsync(() async {
      await userP.init();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: userP),
          Provider<NotificationLocalService>.value(value: notification),
        ],
        child: MaterialApp(
          navigatorObservers: [navObserver],
          initialRoute: '/',
          routes: {
            '/': (_) => const SplashPage(),
            '/home': (_) => const Scaffold(
                  body: Center(child: Text('HOME')),
                ),
          },
        ),
      ),
    );

    // 首帧
    await tester.pump();

    // 先整体推进一段时间（覆盖 Splash 内部延迟：你备注的 1150ms，这里给更稳冗余）
    await tester.pump(const Duration(milliseconds: 1500));

    // 再用有限步进等待 HOME 出现（不会无限卡住）
    await _pumpUntilFound(tester, find.text('HOME'));

    expect(find.text('HOME'), findsOneWidget);
    expect(notification.ensured, isTrue);

    // 可选：确认确实发生过 /home 导航（push 或 replace）
    final pushedNames = navObserver.pushed
        .map((r) => r.settings.name)
        .whereType<String>()
        .toList();
    final replacedNames = navObserver.replacedNew
        .map((r) => r.settings.name)
        .whereType<String>()
        .toList();

    expect(
      pushedNames.contains('/home') || replacedNames.contains('/home'),
      isTrue,
      reason: 'Expected SplashPage to navigate to /home (push or replace).',
    );
  });
}


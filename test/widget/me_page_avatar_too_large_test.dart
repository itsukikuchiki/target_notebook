import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:target_notebook/pages/me_page.dart';
import 'package:target_notebook/providers/settings_provider.dart';
import 'package:target_notebook/providers/user_provider.dart';
import 'package:target_notebook/services/notification_local_service.dart';

import '../helpers/hive_test_env.dart';
import '../fakes/always_ready_notification_local_service.dart';

Future<void> _pumpFor(
  WidgetTester tester,
  Duration total, {
  Duration step = const Duration(milliseconds: 50),
}) async {
  final steps = (total.inMilliseconds / step.inMilliseconds).ceil();
  for (var i = 0; i < steps; i++) {
    await tester.pump(step);
  }
}

/// FakeAsync-safe waiting: loop fixed times.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 120, // 120 * 50ms = 6s
  Duration step = const Duration(milliseconds: 50),
  required String onTimeoutMessage,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(step);
  }
  throw TestFailure(onTimeoutMessage);
}

/// ✅ Test-only SettingsProvider: avoid real init() (hangs in widget tests).
class _TestSettingsProvider extends SettingsProvider {
  @override
  Future<void> init() async {}
}

/// ✅ Test-only UserProvider: avoid real init() (hangs in widget tests).
class _TestUserProvider extends UserProvider {
  @override
  Future<void> init() async {}
}

/// Fake File that reports >2MB without touching real filesystem.
/// MePage uses File.length(), so length() must be >2MB.
class _FakeBigFile implements File {
  _FakeBigFile(this._path);

  final String _path;
  static const int _size = 2 * 1024 * 1024 + 10;

  @override
  String get path => _path;

  @override
  Future<bool> exists() async => true;

  @override
  bool existsSync() => true;

  @override
  Future<int> length() async => _size;

  @override
  int lengthSync() => _size;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);

  @override
  Uint8List readAsBytesSync() => Uint8List(0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel imagePickerChannel = MethodChannel('plugins.flutter.io/image_picker');

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

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(imagePickerChannel, null);
  });

  testWidgets(
    'MePage avatar: file > 2MB -> blocked with SnackBar and does not save path',
    (tester) async {
      const fakeBigAvatarPath = '/__test__/avatar_big.png';
      final calls = <String>[];

      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      // ✅ IMPORTANT: image_picker expects a String path return in many versions.
      messenger.setMockMethodCallHandler(imagePickerChannel, (MethodCall call) async {
        calls.add('image_picker:${call.method}');
        debugPrint('STEP: image_picker call=${call.method} args=${call.arguments}');
        if (call.method == 'pickImage' || call.method == 'getImage') {
          return fakeBigAvatarPath; // String
        }
        return null;
      });

      final settings = _TestSettingsProvider();
      final user = _TestUserProvider();
      final notif = AlwaysReadyNotificationLocalService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UserProvider>.value(value: user),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            Provider<NotificationLocalService>.value(value: notif),
          ],
          child: const MaterialApp(home: Scaffold(body: MePage())),
        ),
      );

      await _pumpFor(tester, const Duration(milliseconds: 600));

      final changeBtn = find.byWidgetPredicate((w) {
        return w is IconButton && w.tooltip == 'Change avatar';
      });
      expect(changeBtn, findsOneWidget);

      // Tap and run size-check under IOOverrides.
      await IOOverrides.runZoned(
        () async {
          await tester.tap(changeBtn);
          await tester.pump();

          final tooBig = find.text('头像过大，请选择 2MB 以内的图片');
          final failed = find.byWidgetPredicate((w) {
            return w is Text && w.data != null && w.data!.startsWith('选择头像失败：');
          });

          await _pumpUntilFound(
            tester,
            find.byWidgetPredicate((_) =>
                tooBig.evaluate().isNotEmpty || failed.evaluate().isNotEmpty),
            onTimeoutMessage:
                'No expected SnackBar shown. Platform calls observed: $calls.',
          );

          if (failed.evaluate().isNotEmpty) {
            final msg = (failed.evaluate().first.widget as Text).data;
            throw TestFailure('MePage showed failure snackbar: $msg');
          }
        },
        createFile: (path) {
          if (path == fakeBigAvatarPath) return _FakeBigFile(path);
          return File(path);
        },
      );

      expect(find.text('头像过大，请选择 2MB 以内的图片'), findsOneWidget);
      expect(settings.avatarPath, isNull);

      // ✅ Let SnackBar's internal timer finish (default ~4s) to avoid pending timers.
      await tester.pump(const Duration(seconds: 5));

      // ✅ Dispose widget tree cleanly.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}

// test/widget/me_page_avatar_picker_test.dart
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

import '../fakes/always_ready_notification_local_service.dart';
import '../helpers/hive_test_env.dart';
import '../helpers/pump_settle_safe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel imagePickerChannel =
      MethodChannel('plugins.flutter.io/image_picker');

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

  Future<void> _pumpOpen(WidgetTester tester) async {
    await pumpFrames(tester, frames: 3);
    await tester.pump(const Duration(milliseconds: 150));
  }

  Future<void> _pumpPage(
    WidgetTester tester, {
    required UserProvider user,
    required SettingsProvider settings,
    required NotificationLocalService notif,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: user),
          ChangeNotifierProvider.value(value: settings),
          Provider<NotificationLocalService>.value(value: notif),
        ],
        child: const TickerMode(
          enabled: false,
          child: MaterialApp(home: Scaffold(body: MePage())),
        ),
      ),
    );

    await _pumpOpen(tester);
  }

  testWidgets(
    'MePage: pick avatar success -> saves path + shows SnackBar + renders Image.file',
    (tester) async {
      final tmpDir = await Directory.systemTemp.createTemp('avatar_test_');
      final avatarFile = File('${tmpDir.path}/avatar.png');

      await avatarFile.writeAsBytes(
        Uint8List.fromList(List<int>.generate(256, (i) => i % 255)),
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(imagePickerChannel, (MethodCall call) async {
        if (call.method == 'pickImage' || call.method == 'getImage') {
          return <String, dynamic>{'path': avatarFile.path};
        }
        return null;
      });

      final settings = SettingsProvider();
      await settings.init();

      final user = UserProvider();
      await user.init();

      final notif = AlwaysReadyNotificationLocalService();

      await _pumpPage(
        tester,
        user: user,
        settings: settings,
        notif: notif,
      );

      await tester.tap(find.byKey(const Key('me.avatar.change')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await pumpFrames(tester, frames: 2);

      expect(find.text('头像已更新'), findsOneWidget);
      expect(settings.avatarPath, avatarFile.path);

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images.isNotEmpty, true);

      final hasFileImage = images.any((img) {
        final provider = img.image;
        return provider is FileImage && provider.file.path == avatarFile.path;
      });
      expect(hasFileImage, true);

      try {
        await tmpDir.delete(recursive: true);
      } catch (_) {}

      await pumpAndSettleSafe(tester, maxFrames: 20);
    },
  );

  testWidgets(
    'MePage: pick avatar too large (>2MB) -> shows SnackBar and does NOT save path',
    (tester) async {
      final tmpDir = await Directory.systemTemp.createTemp('avatar_large_test_');
      final avatarFile = File('${tmpDir.path}/avatar_large.png');

      final bytes = Uint8List.fromList(
        List<int>.generate(2 * 1024 * 1024 + 1, (i) => i % 251),
      );
      await avatarFile.writeAsBytes(bytes);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(imagePickerChannel, (MethodCall call) async {
        if (call.method == 'pickImage' || call.method == 'getImage') {
          return <String, dynamic>{'path': avatarFile.path};
        }
        return null;
      });

      final settings = SettingsProvider();
      await settings.init();

      final user = UserProvider();
      await user.init();

      final notif = AlwaysReadyNotificationLocalService();

      await _pumpPage(
        tester,
        user: user,
        settings: settings,
        notif: notif,
      );

      await tester.tap(find.byKey(const Key('me.avatar.change')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await pumpFrames(tester, frames: 2);

      expect(find.text('头像过大，请选择 2MB 以内的图片'), findsOneWidget);
      expect(settings.avatarPath, isNull);

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      final hasFileImage = images.any((img) => img.image is FileImage);
      expect(hasFileImage, false);

      try {
        await tmpDir.delete(recursive: true);
      } catch (_) {}

      await pumpAndSettleSafe(tester, maxFrames: 20);
    },
  );

  testWidgets(
    'MePage: pick avatar canceled (returns null) -> no-op (no SnackBar, no path change)',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(imagePickerChannel, (MethodCall call) async {
        if (call.method == 'pickImage' || call.method == 'getImage') {
          return null;
        }
        return null;
      });

      final settings = SettingsProvider();
      await settings.init();

      final user = UserProvider();
      await user.init();

      final notif = AlwaysReadyNotificationLocalService();

      await _pumpPage(
        tester,
        user: user,
        settings: settings,
        notif: notif,
      );

      await tester.tap(find.byKey(const Key('me.avatar.change')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await pumpFrames(tester, frames: 2);

      expect(find.text('头像已更新'), findsNothing);
      expect(find.text('头像过大，请选择 2MB 以内的图片'), findsNothing);
      expect(find.textContaining('选择头像失败'), findsNothing);
      expect(settings.avatarPath, isNull);

      await pumpAndSettleSafe(tester, maxFrames: 20);
    },
  );
}

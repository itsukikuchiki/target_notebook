import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';

import 'package:target_notebook/pages/me_page.dart';
import 'package:target_notebook/providers/settings_provider.dart';
import 'package:target_notebook/providers/user_provider.dart';
import 'package:target_notebook/services/notification_service_interface.dart';

import '../fakes/fake_user_provider.dart';
import '../helpers/pump_settle_safe.dart';

class _NotifNoop implements NotificationService {
  @override
  bool get isReady => true;
  @override
  Future<void> init() async {}
  @override
  Future<void> ensureReady() async {}
  @override
  Future<void> scheduleOne({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {}
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> cancelAll() async {}
}

class _AvatarSettingsProvider extends ChangeNotifier implements SettingsProvider {
  SoundId _soundId;
  WeekStart _weekStart;
  bool _seenOnboarding;
  bool _inited;
  String? _avatarPath;

  _AvatarSettingsProvider({
    SoundId soundId = SoundId.none,
    WeekStart weekStart = WeekStart.monday,
    bool seenOnboarding = true,
    bool inited = true,
  })  : _soundId = soundId,
        _weekStart = weekStart,
        _seenOnboarding = seenOnboarding,
        _inited = inited;

  @override
  bool get inited => _inited;

  @override
  Future<void> init() async {
    _inited = true;
  }

  @override
  WeekStart get weekStart => _weekStart;

  @override
  Future<void> setWeekStart(WeekStart v) async {
    _weekStart = v;
    notifyListeners();
  }

  @override
  SoundId get soundId => _soundId;

  @override
  Future<void> setSoundId(SoundId v) async {
    _soundId = v;
    notifyListeners();
  }

  @override
  String? get avatarPath => _avatarPath;

  @override
  File? get avatarFile {
    final p = _avatarPath;
    if (p == null || p.isEmpty) return null;
    final f = File(p);
    return f.existsSync() ? f : null;
  }

  @override
  Future<void> setAvatarPath(String? path) async {
    _avatarPath = path;
    notifyListeners();
  }

  @override
  Future<void> clearAvatar() async {
    _avatarPath = null;
    notifyListeners();
  }

  @override
  bool get seenOnboarding => _seenOnboarding;

  @override
  Future<void> setSeenOnboarding(bool v) async {
    _seenOnboarding = v;
    notifyListeners();
  }
}

class _FakeImagePickerPlatform extends ImagePickerPlatform
    with MockPlatformInterfaceMixin {
  String? pickedPath;
  int callCount = 0;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    callCount++;
    debugPrint('[avatar_test] picker called path=$pickedPath');
    final p = pickedPath;
    if (p == null) return null;
    return XFile(p);
  }

  @override
  Future<XFile?> getImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    callCount++;
    final p = pickedPath;
    if (p == null) return null;
    return XFile(p);
  }

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async => const <XFile>[];

  @override
  Future<LostDataResponse> getLostData() async => LostDataResponse.empty();
}

class _FakeSizedFile implements File {
  _FakeSizedFile(this._path, this._len, this._bytes);
  final String _path;
  final int _len;
  final Uint8List _bytes;

  @override
  String get path => _path;

  @override
  Future<bool> exists() async => true;
  @override
  bool existsSync() => true;
  @override
  Future<int> length() async => _len;
  @override
  int lengthSync() => _len;
  @override
  Future<Uint8List> readAsBytes() async => _bytes;
  @override
  Uint8List readAsBytesSync() => _bytes;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ImagePickerPlatform originalPlatform;
  late _FakeImagePickerPlatform fakePicker;

  setUp(() {
    originalPlatform = ImagePickerPlatform.instance;
    fakePicker = _FakeImagePickerPlatform();
    ImagePickerPlatform.instance = fakePicker;
  });

  tearDown(() {
    ImagePickerPlatform.instance = originalPlatform;
  });

  Future<void> _pumpPage(
    WidgetTester tester, {
    required UserProvider user,
    required SettingsProvider settings,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: user),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          Provider<NotificationService>.value(value: _NotifNoop()),
        ],
        child: const MaterialApp(home: Scaffold(body: MePage())),
      ),
    );

    await pumpFrames(tester, frames: 2);
    await tester.pump(const Duration(milliseconds: 80));
  }

  Uint8List _validPngBytes() {
    return Uint8List.fromList(const <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82,
    ]);
  }

  Future<void> _pumpUntil(
    WidgetTester tester, {
    required bool Function() done,
    int maxPumps = 80,
    Duration step = const Duration(milliseconds: 50),
    required String onTimeoutMessage,
  }) async {
    for (var i = 0; i < maxPumps; i++) {
      if (done()) return;
      await tester.pump(step);
    }
    throw TestFailure(onTimeoutMessage);
  }

  testWidgets(
    'MePage: pick avatar success -> saves path + shows SnackBar + renders Image.file',
    (tester) async {
      debugPrint('[avatar_test] success:start');
      const avatarPath = '/__avatar__/ok.png';
      fakePicker.pickedPath = avatarPath;

      final settings = _AvatarSettingsProvider();
      final user = FakeUserProvider();

      await _pumpPage(tester, user: user, settings: settings);

      await IOOverrides.runZoned(
        () async {
          debugPrint('[avatar_test] success:before tap');
          await tester.tap(find.byKey(MePage.avatarButtonKey));
          await tester.pump();

          await _pumpUntil(
            tester,
            done: () => fakePicker.callCount > 0,
            onTimeoutMessage: 'picker not called',
          );

          await _pumpUntil(
            tester,
            done: () => find.text('头像已更新').evaluate().isNotEmpty,
            onTimeoutMessage: 'success snackbar not shown',
          );
        },
        createFile: (path) {
          if (path == avatarPath) return _FakeSizedFile(path, 1024, _validPngBytes());
          return File(path);
        },
      );

      expect(fakePicker.callCount > 0, true);
      expect(find.text('头像已更新'), findsOneWidget);
      expect(settings.avatarPath, avatarPath);
      debugPrint('[avatar_test] success:end');
    },
  );

  testWidgets(
    'MePage: pick avatar too large (>2MB) -> shows SnackBar and does NOT save path',
    (tester) async {
      const avatarPath = '/__avatar__/large.png';
      fakePicker.pickedPath = avatarPath;

      final settings = _AvatarSettingsProvider();
      final user = FakeUserProvider();

      await _pumpPage(tester, user: user, settings: settings);

      await IOOverrides.runZoned(
        () async {
          await tester.tap(find.byKey(MePage.avatarButtonKey));
          await tester.pump();

          await _pumpUntil(
            tester,
            done: () => find.text('头像过大，请选择 2MB 以内的图片').evaluate().isNotEmpty,
            onTimeoutMessage: 'too-large snackbar not shown',
          );
        },
        createFile: (path) {
          if (path == avatarPath) {
            return _FakeSizedFile(path, 2 * 1024 * 1024 + 1, _validPngBytes());
          }
          return File(path);
        },
      );

      expect(settings.avatarPath, isNull);
      debugPrint('[avatar_test] large:end');
    },
  );

  testWidgets(
    'MePage: pick avatar canceled (returns null) -> no-op (no SnackBar, no path change)',
    (tester) async {
      fakePicker.pickedPath = null;

      final settings = _AvatarSettingsProvider();
      final user = FakeUserProvider();

      await _pumpPage(tester, user: user, settings: settings);

      await tester.tap(find.byKey(MePage.avatarButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('头像已更新'), findsNothing);
      expect(find.text('头像过大，请选择 2MB 以内的图片'), findsNothing);
      expect(find.textContaining('选择头像失败'), findsNothing);
      expect(settings.avatarPath, isNull);
      debugPrint('[avatar_test] cancel:end');
    },
  );
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:target_notebook/providers/settings_provider.dart';

import '../helpers/hive_test_env.dart';

void main() {
  group('SettingsProvider persistence', () {
    setUp(() async {
      await HiveTestEnv.setUp();
    });

    tearDown(() async {
      await HiveTestEnv.tearDown();
    });

    test('init sets defaults', () async {
      final p = SettingsProvider();
      await p.init();

      expect(p.weekStart, WeekStart.monday);
      expect(p.soundId, SoundId.none);
      expect(p.avatarPath, isNull);
      expect(p.seenOnboarding, false);
    });

    test('set/get persists after reopen', () async {
      final p = SettingsProvider();
      await p.init();

      await p.setWeekStart(WeekStart.sunday);
      await p.setSoundId(SoundId.bell);
      await p.setSeenOnboarding(true);
      await p.setAvatarPath('/tmp/avatar.png');

      expect(p.weekStart, WeekStart.sunday);
      expect(p.soundId, SoundId.bell);
      expect(p.seenOnboarding, true);
      expect(p.avatarPath, '/tmp/avatar.png');

      // simulate reboot: close/open box and re-init new provider
      await Hive.box<dynamic>(SettingsProvider.boxName).close();

      final p2 = SettingsProvider();
      await p2.init();

      expect(p2.weekStart, WeekStart.sunday);
      expect(p2.soundId, SoundId.bell);
      expect(p2.seenOnboarding, true);
      expect(p2.avatarPath, '/tmp/avatar.png');
    });

    test('clearAvatar removes file and clears path', () async {
      final dir = await Directory.systemTemp.createTemp('tn_avatar_');
      final f = File('${dir.path}/a.png');
      await f.writeAsBytes(List<int>.filled(16, 7));

      final p = SettingsProvider();
      await p.init();

      await p.setAvatarPath(f.path);
      expect(p.avatarFile, isNotNull);

      await p.clearAvatar();

      expect(p.avatarPath, isNull);
      expect(f.existsSync(), false);

      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });
  });
}

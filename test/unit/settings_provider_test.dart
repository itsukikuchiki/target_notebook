import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/providers/settings_provider.dart';

import '../helpers/hive_test_env.dart';

void main() {
  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  setUp(() async {
    // SettingsProvider 用的是 boxName='settings'，这里确保清掉
    if (Hive.isBoxOpen(SettingsProvider.boxName)) {
      await Hive.box(SettingsProvider.boxName).clear();
    } else {
      final b = await Hive.openBox<dynamic>(SettingsProvider.boxName);
      await b.clear();
    }
  });

  test('SettingsProvider.init sets defaults when empty', () async {
    final p = SettingsProvider();
    await p.init();

    expect(p.inited, true);
    expect(p.weekStart, WeekStart.monday);
    expect(p.soundId, SoundId.none);
    expect(p.avatarPath, null);
    expect(p.seenOnboarding, false);

    final box = Hive.box(SettingsProvider.boxName);
    expect(box.get(SettingsProvider.kWeekStart), WeekStart.monday.name);
    expect(box.get(SettingsProvider.kSoundId), SoundId.none.name);
    expect(box.get(SettingsProvider.kAvatarPath), null);
    expect(box.get(SettingsProvider.kSeenOnboarding), false);
  });

  test('SettingsProvider setters persist & notify', () async {
    final p = SettingsProvider();
    await p.init();

    var notifyCount = 0;
    p.addListener(() => notifyCount++);

    await p.setWeekStart(WeekStart.sunday);
    await p.setSoundId(SoundId.bell);
    await p.setAvatarPath('/tmp/avatar.png');
    await p.setSeenOnboarding(true);

    expect(p.weekStart, WeekStart.sunday);
    expect(p.soundId, SoundId.bell);
    expect(p.avatarPath, '/tmp/avatar.png');
    expect(p.seenOnboarding, true);
    expect(notifyCount, 4);

    final box = Hive.box(SettingsProvider.boxName);
    expect(box.get(SettingsProvider.kWeekStart), WeekStart.sunday.name);
    expect(box.get(SettingsProvider.kSoundId), SoundId.bell.name);
    expect(box.get(SettingsProvider.kAvatarPath), '/tmp/avatar.png');
    expect(box.get(SettingsProvider.kSeenOnboarding), true);
  });
}


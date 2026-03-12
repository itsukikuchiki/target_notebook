import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/providers/settings_provider.dart';

import '../helpers/hive_test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HiveTestEnv.setUp();
  });

  setUp(() async {
    // settings box 也在 clearHiveBoxes 里会清；但这里直接确保干净
    if (Hive.isBoxOpen(SettingsProvider.boxName)) {
      await Hive.box<dynamic>(SettingsProvider.boxName).clear();
    }
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  test('SettingsProvider.clearAvatar deletes file and clears avatarPath', () async {
    final p = SettingsProvider();
    await p.init();

    // 建一个临时文件作为 avatar
    final dir = await Directory.systemTemp.createTemp('avatar_test_');
    final f = File('${dir.path}/a.png');
    await f.writeAsBytes(List<int>.filled(10, 7));

    expect(f.existsSync(), true);

    await p.setAvatarPath(f.path);
    expect(p.avatarPath, f.path);
    expect(p.avatarFile, isNotNull);

    await p.clearAvatar();

    // 文件应被删（删除失败也不会 throw，但一般在本地测试是可删的）
    expect(f.existsSync(), false);

    // Hive 应被置空
    expect(p.avatarPath, isNull);
    expect(p.avatarFile, isNull);

    // box 里 key 也应 null
    final box = Hive.box<dynamic>(SettingsProvider.boxName);
    expect(box.get(SettingsProvider.kAvatarPath), isNull);

    // cleanup
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });
}

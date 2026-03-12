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
    // settings box 也在 Hive 里，跟其他 box 一样清理
    await clearHiveBoxes();
    if (Hive.isBoxOpen(SettingsProvider.boxName)) {
      await Hive.box(SettingsProvider.boxName).clear();
    }
  });

  tearDownAll(() async {
    await HiveTestEnv.tearDown();
  });

  test('SettingsProvider avatarFile returns file when path exists; clearAvatar deletes file + clears path', () async {
    final p = SettingsProvider();
    await p.init();

    // 准备一个真实文件
    final dir = Directory.systemTemp.createTempSync('avatar_test_');
    final file = File('${dir.path}/avatar.png');
    await file.writeAsBytes(List<int>.filled(10, 7)); // 任意内容

    expect(file.existsSync(), true);

    await p.setAvatarPath(file.path);

    // avatarFile 应该能拿到，并且 existsSync=true
    final f1 = p.avatarFile;
    expect(f1, isNotNull);
    expect(f1!.path, file.path);
    expect(f1.existsSync(), true);

    // clearAvatar 应删除文件，并清空 path
    await p.clearAvatar();

    expect(p.avatarPath, isNull);
    expect(p.avatarFile, isNull);
    expect(file.existsSync(), false);

    // 清理 temp dir
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  test('SettingsProvider avatarFile returns null when file missing; clearAvatar still clears stored path', () async {
    final p = SettingsProvider();
    await p.init();

    final missingPath = '${Directory.systemTemp.path}/no_such_avatar_${DateTime.now().microsecondsSinceEpoch}.png';
    // 确保不存在
    expect(File(missingPath).existsSync(), false);

    await p.setAvatarPath(missingPath);

    // 文件不存在 => avatarFile null
    expect(p.avatarFile, isNull);
    expect(p.avatarPath, missingPath);

    // clearAvatar：因为 avatarFile 为 null，不会尝试 delete，但必须清空路径
    await p.clearAvatar();

    expect(p.avatarPath, isNull);
    expect(p.avatarFile, isNull);
  });
}

// flutter_test_config.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// 这个文件会在每个 `flutter test` 进程启动时运行。
/// 注意：不要在这里使用 `addTearDown`（它只能在单个 test 内部使用）。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // 确保 Widgets 绑定初始化（尤其是需要 WidgetTester 的用例）
  TestWidgetsFlutterBinding.ensureInitialized();

  // 为 Hive 指定一个独立的临时目录，避免不同测试文件之间冲突
  final Directory tmpDir = await Directory.systemTemp.createTemp('tn_test_');
  Hive.init(tmpDir.path);

  // 如果你之前在这里打开过 box 或注册 adapter，务必移到各自的测试里；这里保持“零副作用”。
  // 运行所有测试
  try {
    await testMain();
  } finally {
    // 测试全部结束后统一清理（不要用 addTearDown）
    try {
      await Hive.close();
    } catch (_) {}
    try {
      if (tmpDir.existsSync()) {
        tmpDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  }
}


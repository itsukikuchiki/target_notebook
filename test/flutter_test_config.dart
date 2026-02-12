import 'dart:async';

import 'helpers/hive_test_env.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await ensureHiveReady();

  try {
    await testMain();
  } finally {
    // 清理在本 test suite 中打开/创建的 box，避免互相污染
    await clearHiveBoxes();
  }
}


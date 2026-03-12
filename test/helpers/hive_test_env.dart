// test/helpers/hive_test_env.dart
import 'dart:async';
import 'dart:io';

import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/kpi.dart';
import 'package:target_notebook/models/goal.dart';
import 'package:target_notebook/models/sub_goal.dart';
import 'package:target_notebook/models/task.dart';
import 'package:target_notebook/models/daily_log.dart';
import 'package:target_notebook/models/app_user.dart';

Directory? _hiveTestDir;
bool _hiveInited = false;

/// ✅ 关键：跨 test 文件引用计数
/// - 每个文件 setUpAll -> +1
/// - 每个文件 tearDownAll -> -1
/// - 仅当 refCount 归零时才真正 Hive.close + 删除目录
int _envRefCount = 0;

/// Hive 2.2.3 没有 Hive.boxNames，所以我们自己追踪 test 中打开过的 boxes。
final Set<String> _openedBoxNames = <String>{};

/// ---------------------------------------------------------------------------
/// ✅ 新增：tests 正在用的 API（HiveTestEnv.setUp/tearDown）
/// ---------------------------------------------------------------------------
class HiveTestEnv {
  static Future<void> setUp() async {
    _envRefCount += 1;

    await ensureHiveReady();

    // ✅ tests 里会直接 Hive.box(...)，所以必须提前 open 固定 boxes
    await openTestBox<Goal>(AppBoxes.goal);
    await openTestBox<SubGoal>(AppBoxes.subGoal);
    await openTestBox<Task>(AppBoxes.task);
    await openTestBox<DailyLog>(AppBoxes.dailyLog);
    await openTestBox<AppUser>(AppBoxes.user);
  }

  static Future<void> tearDown() async {
    // ✅ 幂等：多次 tearDown 不会把 refCount 弄成负数
    if (_envRefCount > 0) _envRefCount -= 1;

    // ✅ 不是最后一个使用者：只清空，不 close / delete（避免中途把后续测试环境掀掉）
    if (_envRefCount > 0) {
      await clearHiveBoxes();
      return;
    }

    // ✅ 最后一个：真正释放资源，但必须“永不阻塞”
    final dir = _hiveTestDir;
    if (dir != null) {
      await disposeHiveTest(dir);
    }
  }
}

/// ---------------------------------------------------------------------------
/// 公共工具：清空 Hive boxes（flutter_test_config.dart 在用）
/// ---------------------------------------------------------------------------
Future<void> clearHiveBoxes() async {
  final fixed = <String>{
    AppBoxes.goal,
    AppBoxes.subGoal,
    AppBoxes.task,
    AppBoxes.dailyLog,
    AppBoxes.user,
  };

  final names = <String>{
    ...fixed,
    ..._openedBoxNames,
  }.toList();

  for (final name in names) {
    try {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).clear();
      }
    } catch (_) {
      // ignore
    }
  }
}

/// ---------------------------------------------------------------------------
/// 推荐：通过 helper 打开 box（会自动记录，方便 clearHiveBoxes 清理）
/// ---------------------------------------------------------------------------
Future<Box<T>> openTestBox<T>(String name) async {
  _openedBoxNames.add(name);
  if (Hive.isBoxOpen(name)) return Hive.box<T>(name);
  return Hive.openBox<T>(name);
}

/// ---------------------------------------------------------------------------
/// 旧测试兼容 API：initHiveTest / disposeHiveTest
/// ---------------------------------------------------------------------------
Future<Directory> initHiveTest() async {
  if (_hiveInited && _hiveTestDir != null) return _hiveTestDir!;

  final dir = await Directory.systemTemp.createTemp('target_notebook_hive_test_');
  _hiveTestDir = dir;

  Hive.init(dir.path);

  // ignore: avoid_print
  print('[hive_test_env] Hive.init at ${dir.path}');

  _registerAdaptersIfNeeded();

  // ignore: avoid_print
  print('[hive_test_env] adapters registered');

  _hiveInited = true;
  return dir;
}

Future<void> disposeHiveTest(Directory dir) async {
  // ✅ 不管发生什么：tearDown 不能卡死 test 进程
  // - Hive.close 偶发会挂住（文件句柄 / flush / 平台问题）
  // - dir.delete 偶发会挂住（macOS/Windows 常见）
  Future<void> safeCloseHive() async {
    try {
      // ✅ 尝试先 flush（即使失败也继续）
      for (final name in _openedBoxNames) {
        try {
          if (Hive.isBoxOpen(name)) {
            await Hive.box(name).flush().timeout(const Duration(seconds: 1));
          }
        } catch (_) {
          // ignore
        }
      }

      await Hive.close().timeout(const Duration(seconds: 2));
    } on TimeoutException {
      // ignore: avoid_print
      print('[hive_test_env] Hive.close timeout -> ignore to avoid hanging tests');
    } catch (_) {
      // ignore
    }
  }

  Future<void> safeDeleteDir() async {
    try {
      final exists = await dir.exists().timeout(const Duration(seconds: 1));
      if (!exists) return;

      // ✅ 删除也加 timeout；失败就放过（临时目录残留可接受，挂死不可接受）
      await dir.delete(recursive: true).timeout(const Duration(seconds: 2));
    } on TimeoutException {
      // ignore: avoid_print
      print('[hive_test_env] temp dir delete timeout -> ignore to avoid hanging tests');
    } catch (_) {
      // ignore
    }
  }

  await safeCloseHive();
  await safeDeleteDir();

  if (_hiveTestDir?.path == dir.path) {
    _hiveTestDir = null;
    _hiveInited = false;
    _openedBoxNames.clear();
    _envRefCount = 0;
  }
}

/// ---------------------------------------------------------------------------
/// 你现在 tests 里主要在用的 API：保持不变
/// ---------------------------------------------------------------------------
Future<void> ensureHiveReady() async {
  await initHiveTest();
}

/// ---------------------------------------------------------------------------
/// 🔑 关键：完全复刻 lib/core/hive_init.dart 里的 adapter 注册逻辑
/// （但不调用 Hive.initFlutter，不 open boxes）
/// ---------------------------------------------------------------------------
void _registerAdaptersIfNeeded() {
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(KPIAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(GoalAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(SubGoalAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(TaskAdapter());
  if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(DailyLogAdapter());

  // ✅ 必须注册（否则 userBox 写入会崩）
  if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(AppUserAdapter());
  if (!Hive.isAdapterRegistered(7)) {
    Hive.registerAdapter(AuthProviderTypeAdapter());
  }
}

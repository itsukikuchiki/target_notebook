import 'dart:async';

import 'package:hive/hive.dart';

/// A minimal, test-friendly Hive box opener.
///
/// ✅ Does NOT call path_provider / Hive.initFlutter / any filesystem bootstrap.
/// ✅ Safe in widget tests where Hive.init(tempDir) is already done.
/// ✅ Prevents double-open races via an in-flight Future map.
final class HiveBoxOpener {
  HiveBoxOpener._();

  static final Map<String, Future<Box<dynamic>>> _opening = {};

  static Future<Box<T>> openTyped<T>(String name) async {
    // Fast path: already open
    if (Hive.isBoxOpen(name)) {
      return Hive.box<T>(name);
    }

    // If another caller is opening the same box, await it.
    final existing = _opening[name];
    if (existing != null) {
      final box = await existing;
      return box as Box<T>;
    }

    // Start opening.
    final future = Hive.openBox<T>(name);
    _opening[name] = future.then<Box<dynamic>>((b) => b);

    try {
      final box = await future;
      return box;
    } finally {
      _opening.remove(name);
    }
  }
}

/// Backward-compatible function used across providers.
Future<Box<T>> ensureTypedBox<T>(String boxName) {
  return HiveBoxOpener.openTyped<T>(boxName);
}


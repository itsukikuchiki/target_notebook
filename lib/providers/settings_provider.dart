import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// 周开始日
enum WeekStart { monday, sunday }

/// 提示音（先做“选择&保存”，播放预览可放 1.0.1）
enum SoundId { none, soft, bell }

class SettingsProvider extends ChangeNotifier {
  static const String boxName = 'settings';

  // keys
  static const String kWeekStart = 'weekStart';
  static const String kSoundId = 'soundId';
  static const String kAvatarPath = 'avatarPath';
  static const String kSeenOnboarding = 'seenOnboarding';

  Box<dynamic>? _box;
  bool _inited = false;

  bool get inited => _inited;

  Future<void> init() async {
    if (_inited) return;

    _box = await Hive.openBox<dynamic>(boxName);

    // defaults (Hive Box 没有 putIfAbsent)
    await _ensureDefault(kWeekStart, WeekStart.monday.name);
    await _ensureDefault(kSoundId, SoundId.none.name);
    await _ensureDefault(kAvatarPath, null);
    await _ensureDefault(kSeenOnboarding, false);

    _inited = true;
    notifyListeners();
  }

  Future<void> _ensureDefault(String key, dynamic value) async {
    final box = _box;
    if (box == null) return;
    if (!box.containsKey(key)) {
      await box.put(key, value);
    }
  }

  // -------------------------
  // WeekStart
  // -------------------------
  WeekStart get weekStart {
    final raw = _box?.get(kWeekStart) as String?;
    return WeekStart.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => WeekStart.monday,
    );
  }

  Future<void> setWeekStart(WeekStart v) async {
    await _box?.put(kWeekStart, v.name);
    notifyListeners();
  }

  // -------------------------
  // SoundId
  // -------------------------
  SoundId get soundId {
    final raw = _box?.get(kSoundId) as String?;
    return SoundId.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => SoundId.none,
    );
  }

  Future<void> setSoundId(SoundId v) async {
    await _box?.put(kSoundId, v.name);
    notifyListeners();
  }

  // -------------------------
  // Avatar
  // -------------------------
  String? get avatarPath => _box?.get(kAvatarPath) as String?;

  File? get avatarFile {
    final p = avatarPath;
    if (p == null || p.isEmpty) return null;
    final f = File(p);
    return f.existsSync() ? f : null;
  }

  Future<void> setAvatarPath(String? path) async {
    await _box?.put(kAvatarPath, path);
    notifyListeners();
  }

  Future<void> clearAvatar() async {
    final f = avatarFile;
    if (f != null) {
      try {
        await f.delete();
      } catch (_) {
        // ignore
      }
    }
    await setAvatarPath(null);
  }

  // -------------------------
  // Onboarding flag（给 12/22 用）
  // -------------------------
  bool get seenOnboarding => (_box?.get(kSeenOnboarding) as bool?) ?? false;

  Future<void> setSeenOnboarding(bool v) async {
    await _box?.put(kSeenOnboarding, v);
    notifyListeners();
  }
}


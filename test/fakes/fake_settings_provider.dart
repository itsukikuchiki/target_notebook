// test/fakes/fake_settings_provider.dart
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:target_notebook/providers/settings_provider.dart';

class FakeSettingsProvider extends ChangeNotifier implements SettingsProvider {
  FakeSettingsProvider({
    bool inited = true,
    bool seenOnboarding = true,
    WeekStart weekStart = WeekStart.monday,
    SoundId soundId = SoundId.none,
  })  : _inited = inited,
        _seenOnboarding = seenOnboarding,
        _weekStart = weekStart,
        _soundId = soundId;

  bool _inited;
  bool _seenOnboarding;
  WeekStart _weekStart;
  SoundId _soundId;

  bool clearedAvatar = false;

  @override
  bool get inited => _inited;

  @override
  bool get seenOnboarding => _seenOnboarding;

  @override
  WeekStart get weekStart => _weekStart;

  @override
  SoundId get soundId => _soundId;

  @override
  String? get avatarPath => null;

  @override
  File? get avatarFile => null;

  @override
  Future<void> init() async {
    _inited = true;
  }

  @override
  Future<void> setWeekStart(WeekStart v) async {
    _weekStart = v;
    notifyListeners();
  }

  @override
  Future<void> setSoundId(SoundId v) async {
    _soundId = v;
    notifyListeners();
  }

  @override
  Future<void> setAvatarPath(String? path) async {
    // no-op
  }

  @override
  Future<void> clearAvatar() async {
    clearedAvatar = true;
    notifyListeners();
  }

  @override
  Future<void> setSeenOnboarding(bool v) async {
    _seenOnboarding = v;
    notifyListeners();
  }
}


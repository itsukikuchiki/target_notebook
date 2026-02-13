import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavProvider extends ChangeNotifier {
  static const _kKey = 'nav_index_v1';

  // ✅ 统一 tab index（与 app.dart 保持一致）
  static const int tabJourney = 0;
  static const int tabDaily = 1;
  static const int tabInsight = 2;
  static const int tabReflection = 3;
  static const int tabMe = 4;

  int _index = tabJourney;
  int get index => _index;

  String get title => switch (_index) {
        tabJourney => 'My Journey',
        tabDaily => 'Daily',
        tabInsight => 'Insight',
        tabReflection => 'Reflection',
        tabMe => 'Me',
        _ => '目標手帳',
      };

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _index = sp.getInt(_kKey) ?? tabJourney;
    notifyListeners(); // ✅ 关键：加载后刷新 UI
  }

  Future<void> setIndex(int i) async {
    if (i == _index) return;
    _index = i;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kKey, _index);
  }
}


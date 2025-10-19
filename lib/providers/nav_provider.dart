import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';


class NavProvider extends ChangeNotifier {
static const _kKey = 'nav_index_v1';


int _index = 0;


int get index => _index;


String get title => switch (_index) {
0 => 'My Journey',
1 => 'Daily',
2 => 'Insight',
3 => 'Reflection',
4 => 'Me',
_ => '目標手帳',
};


Future<void> load() async {
final sp = await SharedPreferences.getInstance();
_index = sp.getInt(_kKey) ?? 0;
}


Future<void> setIndex(int i) async {
if (i == _index) return;
_index = i;
notifyListeners();
final sp = await SharedPreferences.getInstance();
await sp.setInt(_kKey, _index);
}
}

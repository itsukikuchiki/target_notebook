// test/providers/nav_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:target_notebook/providers/nav_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NavProvider setIndex 会更新且通知 + 写入 SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});

    final p = NavProvider();
    var notifyCount = 0;
    p.addListener(() => notifyCount++);

    expect(p.index, NavProvider.tabJourney);

    await p.setIndex(NavProvider.tabReflection);

    expect(p.index, NavProvider.tabReflection);
    expect(p.title, 'Reflection');
    expect(notifyCount, 1);

    final sp = await SharedPreferences.getInstance();
    expect(sp.getInt('nav_index_v1'), NavProvider.tabReflection);
  });

  test('NavProvider load 会恢复 index 并 notify', () async {
    SharedPreferences.setMockInitialValues({'nav_index_v1': NavProvider.tabMe});

    final p = NavProvider();
    var notifyCount = 0;
    p.addListener(() => notifyCount++);

    await p.load();

    expect(p.index, NavProvider.tabMe);
    expect(p.title, 'Me');
    expect(notifyCount, 1);
  });
}


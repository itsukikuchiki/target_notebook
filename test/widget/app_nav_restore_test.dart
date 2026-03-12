// test/widget/app_nav_restore_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:target_notebook/providers/nav_provider.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('NavProvider restores last tab index from SharedPreferences', () async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('nav_index_v1', NavProvider.tabReflection); // 3

    final nav = NavProvider();
    await nav.load();

    expect(nav.index, NavProvider.tabReflection);
  });

  test('NavProvider defaults to 0 when SharedPreferences has no saved index', () async {
    final nav = NavProvider();
    await nav.load();

    expect(nav.index, 0);
  });
}


import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:target_notebook/providers/nav_provider.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('NavProvider.load reads last saved index (default=Journey)', () async {
    final nav = NavProvider();

    await nav.load();
    expect(nav.index, NavProvider.tabJourney);

    final sp = await SharedPreferences.getInstance();
    await sp.setInt('nav_index_v1', NavProvider.tabInsight);

    await nav.load();
    expect(nav.index, NavProvider.tabInsight);
    expect(nav.title, 'Insight');
  });

  test('NavProvider.setIndex updates index and persists to SharedPreferences', () async {
    final nav = NavProvider();
    await nav.load();

    var notifyCount = 0;
    nav.addListener(() => notifyCount++);

    await nav.setIndex(NavProvider.tabDaily);

    expect(nav.index, NavProvider.tabDaily);
    expect(nav.title, 'Daily');
    expect(notifyCount, 1);

    final sp = await SharedPreferences.getInstance();
    expect(sp.getInt('nav_index_v1'), NavProvider.tabDaily);

    // set same index should no-op
    await nav.setIndex(NavProvider.tabDaily);
    expect(notifyCount, 1);
  });
}


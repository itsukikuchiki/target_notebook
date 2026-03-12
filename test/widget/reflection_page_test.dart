// test/widget/reflection_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:target_notebook/pages/reflection_page.dart';
import 'package:target_notebook/adapters/dailylog_adapter.dart' as log_ui;

import '../fakes/ui_adapters_fakes.dart';

void main() {
  testWidgets('ReflectionPage renders latest reflections list', (tester) async {
    Provider.debugCheckInvalidValueType = null;

    final fakeDaily = FakeDailyLogAdapter();
    fakeDaily.reflectionsSeed = [
      ReflectionStub(DateTime(2026, 1, 2), '今天做得不错', minutes: 25),
      ReflectionStub(DateTime(2026, 1, 3), '', minutes: 0), // empty content
    ];

    await tester.pumpWidget(
      Provider<log_ui.DailyLogAdapter>.value(
        value: fakeDaily as dynamic,
        child: const MaterialApp(home: ReflectionPage()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Reflection'), findsOneWidget);
    expect(find.text('今天做得不错'), findsOneWidget);
    expect(find.text('(无内容)'), findsOneWidget);

    expect(find.textContaining('25 分钟'), findsOneWidget);
  });
}


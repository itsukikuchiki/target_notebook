import 'package:flutter_test/flutter_test.dart';
import 'package:target_notebook/core_app.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('app builds', (tester) async {
    await tester.pumpWidget(const CoreApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}


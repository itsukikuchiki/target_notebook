import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:target_notebook/pages/legal_page.dart';

class _TestAssetBundle extends CachingAssetBundle {
  _TestAssetBundle(this.data);
  final Map<String, String> data;

  @override
  Future<ByteData> load(String key) async {
    final v = data[key];
    if (v == null) throw FlutterError('Asset not found: $key');
    final bytes = Uint8List.fromList(utf8.encode(v));
    return ByteData.view(bytes.buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final v = data[key];
    if (v == null) throw FlutterError('Asset not found: $key');
    return v;
  }
}

Widget _wrap({
  required Locale locale,
  required AssetBundle bundle,
  required Widget home,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('ja'), Locale('zh'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => DefaultAssetBundle(
      bundle: bundle,
      child: child ?? const SizedBox.shrink(),
    ),
    home: home,
  );
}

void main() {
  testWidgets('LegalPage loads jp file when locale is ja', (tester) async {
    final bundle = _TestAssetBundle({
      'assets/legal/privacy_jp.txt': 'JP PRIVACY TEXT',
      'assets/legal/privacy_zh.txt': 'ZH PRIVACY TEXT',
    });

    await tester.pumpWidget(
      _wrap(
        locale: const Locale('ja'),
        bundle: bundle,
        home: const LegalPage(
          titleText: 'プライバシーポリシー',
          doc: LegalDoc.privacy,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('JP PRIVACY TEXT'), findsOneWidget);
    expect(find.text('ZH PRIVACY TEXT'), findsNothing);
  });

  testWidgets('LegalPage falls back to zh when primary missing', (tester) async {
    final bundle = _TestAssetBundle({
      'assets/legal/terms_zh.txt': 'ZH TERMS TEXT',
    });

    await tester.pumpWidget(
      _wrap(
        locale: const Locale('ja'),
        bundle: bundle,
        home: const LegalPage(
          titleText: '利用規約',
          doc: LegalDoc.terms,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ZH TERMS TEXT'), findsOneWidget);
  });
}


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum LegalDoc { privacy, terms }

class LegalPage extends StatefulWidget {
  const LegalPage({
    super.key,
    required this.titleText,
    required this.doc,
  });

  final String titleText;
  final LegalDoc doc;

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  late final Future<String> _futureText = _load();

  String get _baseName {
    switch (widget.doc) {
      case LegalDoc.privacy:
        return 'privacy';
      case LegalDoc.terms:
        return 'terms';
    }
  }

  /// ja -> jp；zh/zh_* -> zh；其他默认 zh
  String _langCodeForAssets(Locale locale) {
    final lc = (locale.languageCode).toLowerCase();
    if (lc == 'ja') return 'jp';
    if (lc == 'zh') return 'zh';
    return 'zh';
  }

  Future<String> _tryLoad(String assetKey) async {
    // ✅ 关键：使用 DefaultAssetBundle，测试才能注入
    final bundle = DefaultAssetBundle.of(context);
    return bundle.loadString(assetKey);
  }

  Future<String> _load() async {
    // locale 可能在 build 前尚未 ready，但这里 _futureText 初始化在 initState 后、
    // 且 FutureBuilder 会在 build 时触发；因此可以安全读取 Localizations.localeOf。
    final locale = Localizations.localeOf(context);
    final primary = _langCodeForAssets(locale);

    final primaryKey = 'assets/legal/${_baseName}_${primary}.txt';
    final fallbackKey = 'assets/legal/${_baseName}_zh.txt';

    try {
      return await _tryLoad(primaryKey);
    } catch (_) {
      // primary missing -> fallback zh
      try {
        return await _tryLoad(fallbackKey);
      } catch (_) {
        // 发布级：给用户可读错误，而不是崩溃
        return '内容加载失败。\n\nMissing assets:\n- $primaryKey\n- $fallbackKey';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titleText)),
      body: FutureBuilder<String>(
        future: _futureText,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final text = snap.data ?? '内容加载失败。';
          return SelectionArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


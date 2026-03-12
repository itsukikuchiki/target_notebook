import 'package:flutter/widgets.dart';

enum LegalTitleKey { privacy, terms }

class LegalI18n {
  static bool isJa(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    return code == 'ja';
  }

  static String title(BuildContext context, LegalTitleKey key) {
    final ja = isJa(context);
    switch (key) {
      case LegalTitleKey.privacy:
        return ja ? 'プライバシーポリシー' : '隐私政策';
      case LegalTitleKey.terms:
        return ja ? '利用規約' : '利用规约';
    }
  }
}

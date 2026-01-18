enum AppRegion { jp, tw }

class AppConfig {
  static const String _raw = String.fromEnvironment('REGION', defaultValue: 'JP');

  static AppRegion get region {
    switch (_raw.toUpperCase()) {
      case 'TW':
        return AppRegion.tw;
      case 'JP':
      default:
        return AppRegion.jp;
    }
  }

  static String get regionName => region == AppRegion.tw ? 'TW' : 'JP';
}


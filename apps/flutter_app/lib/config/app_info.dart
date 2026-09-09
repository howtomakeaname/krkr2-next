/// Single source of product identity for UI, About, legal copy, and tests.
///
/// Change the constants below, then from `apps/flutter_app` run:
/// `dart run tool/sync_app_identity.dart`
/// to rewrite launcher names, bundle ids, LICENSE, and README.
/// Historical upstream names such as reAAAq's KrKr2 Next stay hardcoded
/// in legal acknowledgements and must not be swept by that script.
class AppInfo {
  AppInfo._();

  static const String nameZh = '下一幕';
  static const String nameEn = 'NextScene';
  static const String nameJa = 'NextScene';
  static const String bundleId = 'com.nextscene.app';
  static const String version = '1.0.0';
  static const int copyrightYear = 2026;

  static const String downloadDisplayRoot = 'Download/$bundleId';

  static String nameForLanguage(String languageCode) {
    final code = languageCode.toLowerCase();
    if (code.startsWith('zh')) return nameZh;
    if (code.startsWith('ja')) return nameJa;
    return nameEn;
  }

  static String copyrightHolderForLanguage(String languageCode) {
    return '${nameForLanguage(languageCode)} Contributors';
  }

  static String copyrightLine(String languageCode, {int? year}) {
    return '© ${year ?? DateTime.now().year} ${nameForLanguage(languageCode)}.';
  }
}

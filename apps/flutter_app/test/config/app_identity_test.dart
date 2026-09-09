import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/config/app_info.dart';
import 'package:flutter_app/l10n/app_localizations_en.dart';
import 'package:flutter_app/l10n/app_localizations_ja.dart';
import 'package:flutter_app/l10n/app_localizations_zh.dart';

void main() {
  final packageRoot = Directory.current;

  test('localized titles and iOS hints read AppInfo', () {
    expect(AppLocalizationsZh().appTitle, AppInfo.nameZh);
    expect(AppLocalizationsEn().appTitle, AppInfo.nameEn);
    expect(AppLocalizationsJa().appTitle, AppInfo.nameJa);
    expect(
      AppLocalizationsZh().noGamesHintIos(AppInfo.nameZh),
      contains(AppInfo.nameZh),
    );
    expect(
      AppLocalizationsEn().importStep2(AppInfo.nameEn),
      contains(AppInfo.nameEn),
    );
  });

  test('Dart library copy does not hardcode the product name', () {
    final forbidden = {AppInfo.nameZh, AppInfo.nameEn, AppInfo.bundleId};
    if (AppInfo.nameJa != AppInfo.nameEn) {
      forbidden.add(AppInfo.nameJa);
    }
    final hits = <String>[];
    for (final entity in Directory(
      '${packageRoot.path}/lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('lib/config/app_info.dart')) continue;
      if (entity.path.contains('/l10n/app_localizations')) continue;
      final source = entity.readAsStringSync();
      for (final token in forbidden) {
        if (source.contains("'$token'") ||
            source.contains('"$token"') ||
            source.contains('>$token>') ||
            source.contains(' $token ')) {
          hits.add('${entity.path}: $token');
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('launcher files and lock stay aligned with AppInfo', () {
    final lock =
        jsonDecode(
              File(
                '${packageRoot.path}/tool/app_identity_lock.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(lock['nameZh'], AppInfo.nameZh);
    expect(lock['nameEn'], AppInfo.nameEn);
    expect(lock['nameJa'], AppInfo.nameJa);
    expect(lock['bundleId'], AppInfo.bundleId);

    final checks = <String, List<String>>{
      'lib/l10n/app_zh.arb': [AppInfo.nameZh],
      'lib/l10n/app_en.arb': [AppInfo.nameEn],
      'lib/l10n/app_ja.arb': [AppInfo.nameJa],
      'ohos/AppScope/app.json5': [AppInfo.bundleId],
      'ohos/AppScope/resources/base/element/string.json': [AppInfo.nameZh],
      'android/app/build.gradle.kts': [AppInfo.bundleId],
      'android/app/src/main/AndroidManifest.xml': [AppInfo.nameZh],
      'ios/Runner/Info.plist': [AppInfo.nameZh, AppInfo.nameEn],
      'macos/Runner/Configs/AppInfo.xcconfig': [
        AppInfo.nameEn,
        AppInfo.bundleId,
      ],
      'linux/CMakeLists.txt': [AppInfo.bundleId],
    };
    for (final entry in checks.entries) {
      final text = File('${packageRoot.path}/${entry.key}').readAsStringSync();
      for (final token in entry.value) {
        expect(text, contains(token), reason: entry.key);
      }
    }
  });
}

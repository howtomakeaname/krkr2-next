import 'dart:convert';
import 'dart:io';

import 'package:flutter_app/config/app_info.dart';

/// Rewrites launcher names, bundle ids, LICENSE, and README after
/// [AppInfo] changes. From `apps/flutter_app`:
/// `dart run tool/sync_app_identity.dart`
void main() {
  final packageRoot = Directory.current;
  final lockFile = File('${packageRoot.path}/tool/app_identity_lock.json');
  final previous = Identity.read(lockFile);
  final current = Identity.fromAppInfo();
  if (previous == current) {
    stdout.writeln('App identity already synced.');
    return;
  }

  var changedFiles = 0;
  for (final relative in identityFiles) {
    final file = File('${packageRoot.path}/$relative');
    if (!file.existsSync()) {
      stderr.writeln('skip missing $relative');
      continue;
    }
    final before = file.readAsStringSync();
    final after = swapIdentity(before, from: previous, to: current);
    if (after != before) {
      file.writeAsStringSync(after);
      changedFiles += 1;
      stdout.writeln('updated $relative');
    }
  }
  lockFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(current.toJson())}\n',
  );
  stdout.writeln('wrote tool/app_identity_lock.json ($changedFiles files)');
}

class Identity {
  const Identity({
    required this.nameZh,
    required this.nameEn,
    required this.nameJa,
    required this.bundleId,
  });

  final String nameZh;
  final String nameEn;
  final String nameJa;
  final String bundleId;

  factory Identity.fromAppInfo() => const Identity(
    nameZh: AppInfo.nameZh,
    nameEn: AppInfo.nameEn,
    nameJa: AppInfo.nameJa,
    bundleId: AppInfo.bundleId,
  );

  factory Identity.read(File file) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return Identity(
      nameZh: json['nameZh'] as String,
      nameEn: json['nameEn'] as String,
      nameJa: json['nameJa'] as String,
      bundleId: json['bundleId'] as String,
    );
  }

  Map<String, String> toJson() => {
    'nameZh': nameZh,
    'nameEn': nameEn,
    'nameJa': nameJa,
    'bundleId': bundleId,
  };

  @override
  bool operator ==(Object other) =>
      other is Identity &&
      other.nameZh == nameZh &&
      other.nameEn == nameEn &&
      other.nameJa == nameJa &&
      other.bundleId == bundleId;

  @override
  int get hashCode => Object.hash(nameZh, nameEn, nameJa, bundleId);
}

String swapIdentity(
  String source, {
  required Identity from,
  required Identity to,
}) {
  var next = source.replaceAll(from.bundleId, to.bundleId);
  next = next.replaceAll(from.nameZh, to.nameZh);
  if (from.nameJa != from.nameEn) {
    next = next.replaceAll(from.nameJa, to.nameJa);
  }
  return next.replaceAll(from.nameEn, to.nameEn);
}

const identityFiles = <String>[
  'lib/l10n/app_zh.arb',
  'lib/l10n/app_en.arb',
  'lib/l10n/app_ja.arb',
  'ohos/AppScope/app.json5',
  'ohos/AppScope/resources/base/element/string.json',
  'ohos/entry/src/main/resources/base/element/string.json',
  'ohos/entry/src/main/resources/zh_CN/element/string.json',
  'ohos/entry/src/main/resources/en_US/element/string.json',
  'android/app/src/main/AndroidManifest.xml',
  'android/app/build.gradle.kts',
  'ios/Runner/Info.plist',
  'ios/Runner.xcodeproj/project.pbxproj',
  'macos/Runner/Configs/AppInfo.xcconfig',
  'macos/Runner.xcodeproj/project.pbxproj',
  'macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme',
  'linux/CMakeLists.txt',
  'windows/runner/Runner.rc',
  'windows/runner/main.cpp',
  '../../LICENSE',
  '../../README.md',
  '../../README_EN.md',
];

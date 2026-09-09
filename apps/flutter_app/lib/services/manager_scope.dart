import 'package:path/path.dart' as p;

import '../config/app_info.dart';

/// Dedicated Downloads subtree that file management is allowed to touch.
///
/// The grant is the application folder itself (`Download/<appId>/`), not the
/// `games/` container and not the shared Downloads directory.
class ManagerGrant {
  const ManagerGrant({
    required this.rootPath,
    required this.gamesPath,
    required this.displayRoot,
    required this.appId,
    required this.platform,
  });

  final String rootPath;
  final String gamesPath;
  final String displayRoot;
  final String appId;
  final String platform;

  Map<String, String> toJson() => {
    'rootPath': rootPath,
    'gamesPath': gamesPath,
    'displayRoot': displayRoot,
    'appId': appId,
    'platform': platform,
  };

  factory ManagerGrant.fromJson(Map<String, dynamic> json) {
    return ManagerGrant(
      rootPath: json['rootPath'] as String,
      gamesPath: json['gamesPath'] as String,
      displayRoot: json['displayRoot'] as String,
      appId: json['appId'] as String,
      platform: json['platform'] as String,
    );
  }
}

/// Path policy for the manage tab. Authorization is not "whatever folder the
/// picker returned"; only this app's Downloads child is accepted.
class ManagerScope {
  ManagerScope._();

  static const ohosAndroidAppId = AppInfo.bundleId;
  static const appleAppId = AppInfo.bundleId;

  static String expectedAppId(String platform) {
    return platform == 'ios' || platform == 'macos'
        ? appleAppId
        : ohosAndroidAppId;
  }

  static String displayRoot(String appId) => 'Download/$appId';

  /// Returns the authorized root when [selected] is exactly the dedicated
  /// folder or its `games` child. Content URIs and other providers are
  /// rejected so Android SAF is never treated as a dart:io path.
  static String? dedicatedRoot(
    String selected, {
    required String appId,
    required String platform,
  }) {
    final trimmed = selected.trim();
    if (trimmed.isEmpty) return null;
    if (_isNonFileUri(trimmed)) return null;

    final path = p.normalize(
      p.absolute(
        trimmed.startsWith('file://') ? Uri.parse(trimmed).path : trimmed,
      ),
    );
    final parts = p.split(path).where((part) => part.isNotEmpty).toList();
    if (parts.length < 2) return null;

    var cursor = parts;
    if (cursor.last.toLowerCase() == 'games') {
      cursor = cursor.sublist(0, cursor.length - 1);
    }
    if (cursor.length < 2) return null;
    if (!_sameId(cursor.last, appId)) return null;
    if (!_isDownloadsName(cursor[cursor.length - 2])) return null;
    return p.joinAll([p.rootPrefix(path), ...cursor]);
  }

  static ManagerGrant? grantFromSelection(
    String selected, {
    required String appId,
    required String platform,
  }) {
    final root = dedicatedRoot(selected, appId: appId, platform: platform);
    if (root == null) return null;
    return ManagerGrant(
      rootPath: root,
      gamesPath: p.join(root, 'games'),
      displayRoot: displayRoot(appId),
      appId: appId,
      platform: platform,
    );
  }

  static bool matches(
    ManagerGrant grant, {
    required String appId,
    required String platform,
  }) {
    if (grant.appId != appId || grant.platform != platform) return false;
    final root = dedicatedRoot(
      grant.rootPath,
      appId: appId,
      platform: platform,
    );
    return root != null && p.equals(root, grant.rootPath);
  }

  static bool _isNonFileUri(String value) {
    final separator = value.indexOf('://');
    if (separator < 0) return false;
    return value.substring(0, separator).toLowerCase() != 'file';
  }

  static bool _isDownloadsName(String name) {
    final lower = name.toLowerCase();
    return lower == 'download' || lower == 'downloads';
  }

  static bool _sameId(String left, String right) =>
      left.toLowerCase() == right.toLowerCase();
}

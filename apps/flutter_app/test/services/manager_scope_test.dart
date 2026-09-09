import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/manager_scope.dart';

void main() {
  const appId = ManagerScope.ohosAndroidAppId;
  const appleId = ManagerScope.appleAppId;

  test('accepts the dedicated Download child and its games folder', () {
    final root = ManagerScope.dedicatedRoot(
      '/storage/Users/currentUser/Download/$appId',
      appId: appId,
      platform: 'ohos',
    );
    expect(root, '/storage/Users/currentUser/Download/$appId');
    expect(
      ManagerScope.dedicatedRoot(
        '/storage/Users/currentUser/Download/$appId/games',
        appId: appId,
        platform: 'ohos',
      ),
      root,
    );
  });

  test('rejects Downloads itself, other apps, and content URIs', () {
    for (final selected in [
      '/storage/Users/currentUser/Download',
      '/storage/Users/currentUser/Download/other.app',
      '/data/storage/el2/base/files',
      'content://com.android.externalstorage.documents/tree/primary:Download/$appId',
      'docs://storage/Users/currentUser/Download/$appId',
      '/Users/me/Documents/$appId',
    ]) {
      expect(
        ManagerScope.dedicatedRoot(selected, appId: appId, platform: 'android'),
        isNull,
        reason: selected,
      );
    }
  });

  test('all platforms share the current product bundle id', () {
    expect(appId, appleId);
    expect(ManagerScope.expectedAppId('ios'), appleId);
    expect(ManagerScope.expectedAppId('macos'), appleId);
    expect(ManagerScope.expectedAppId('ohos'), appId);
    expect(ManagerScope.expectedAppId('android'), appId);
    expect(
      ManagerScope.dedicatedRoot(
        '/Users/me/Downloads/$appleId',
        appId: appleId,
        platform: 'macos',
      ),
      '/Users/me/Downloads/$appleId',
    );
    expect(
      ManagerScope.dedicatedRoot(
        '/Users/me/Downloads/other.app',
        appId: appleId,
        platform: 'macos',
      ),
      isNull,
    );
  });

  test('persisted grants must still match the current platform identity', () {
    final grant = ManagerScope.grantFromSelection(
      '/tmp/Downloads/$appId',
      appId: appId,
      platform: 'linux',
    )!;
    expect(
      ManagerScope.matches(grant, appId: appId, platform: 'linux'),
      isTrue,
    );
    expect(
      ManagerScope.matches(grant, appId: appleId, platform: 'macos'),
      isFalse,
    );
  });
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps the HarmonyOS application configuration in sync with Flutter's
/// selected theme. Other platforms only need MaterialApp.themeMode.
abstract final class AppThemePlatform {
  static const MethodChannel _channel = MethodChannel('flutter_engine_bridge');

  static Future<void> apply(String mode) async {
    if (Platform.operatingSystem != 'ohos') return;

    try {
      await _channel.invokeMethod<void>(
        'setApplicationColorMode',
        <String, String>{'mode': mode},
      );
    } on PlatformException catch (error) {
      debugPrint('Failed to update OHOS application color mode: $error');
    } on MissingPluginException {
      // Older OHOS builds keep using the mode read on the next launch.
    }
  }
}

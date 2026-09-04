import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/config/app_theme_mode.dart';
import 'package:flutter_app/l10n/app_localizations.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/pages/home_page.dart';
import 'package:flutter_app/pages/settings_page.dart';
import 'package:flutter_app/ui/ui.dart';

class _ThemeCase {
  const _ThemeCase({
    required this.name,
    required this.mode,
    required this.systemBrightness,
    required this.expectedBrightness,
  });

  final String name;
  final ThemeMode mode;
  final Brightness systemBrightness;
  final Brightness expectedBrightness;
}

void main() {
  test('persisted theme codes include system, light, and dark', () {
    expect(AppThemeMode.fromCode(AppThemeMode.system), ThemeMode.system);
    expect(AppThemeMode.fromCode(AppThemeMode.light), ThemeMode.light);
    expect(AppThemeMode.fromCode(AppThemeMode.dark), ThemeMode.dark);
    expect(AppThemeMode.fromCode('unsupported'), ThemeMode.dark);
  });

  const cases = <_ThemeCase>[
    _ThemeCase(
      name: 'explicit light stays light while the system is dark',
      mode: ThemeMode.light,
      systemBrightness: Brightness.dark,
      expectedBrightness: Brightness.light,
    ),
    _ThemeCase(
      name: 'explicit dark stays dark while the system is light',
      mode: ThemeMode.dark,
      systemBrightness: Brightness.light,
      expectedBrightness: Brightness.dark,
    ),
    _ThemeCase(
      name: 'system mode resolves to system light',
      mode: ThemeMode.system,
      systemBrightness: Brightness.light,
      expectedBrightness: Brightness.light,
    ),
    _ThemeCase(
      name: 'system mode resolves to system dark',
      mode: ThemeMode.system,
      systemBrightness: Brightness.dark,
      expectedBrightness: Brightness.dark,
    ),
  ];

  for (final themeCase in cases) {
    testWidgets(themeCase.name, (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.platformDispatcher.platformBrightnessTestValue =
          themeCase.systemBrightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(Krkr2App(initialThemeMode: themeCase.mode));

      final homeContext = tester.element(find.byType(HomePage));
      expect(Theme.of(homeContext).brightness, themeCase.expectedBrightness);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('settings exposes system, light, and dark theme choices', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: UiTheme.light(),
        home: const SettingsPage(
          engineMode: EngineMode.builtIn,
          customDylibPath: null,
          builtInDylibPath: null,
          builtInAvailable: true,
          perfOverlay: false,
          fpsLimitEnabled: false,
          targetFps: 60,
          renderer: 'opengl',
          angleBackend: 'gles',
          gameOrientation: 'landscape',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('主题'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('主题'));
    await tester.pumpAndSettle();

    expect(find.text('跟随系统'), findsAtLeastNWidgets(1));
    expect(find.text('浅色'), findsAtLeastNWidgets(1));
    expect(find.text('深色'), findsAtLeastNWidgets(1));
  });
}

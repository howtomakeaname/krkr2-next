import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_theme_mode.dart';
import 'config/stats_base_url.dart'
    if (dart.library.io) 'config/stats_base_url_io.dart';
import 'constants/prefs_keys.dart';
import 'l10n/app_localizations.dart';
import 'pages/home_page.dart';
import 'services/app_theme_platform.dart';
import 'services/first_open_analytics.dart';
import 'ui/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Locale? initialLocale;
  var initialThemeCode = AppThemeMode.defaultCode;
  var initialThemeMode = ThemeMode.dark;
  try {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(PrefsKeys.locale);
    if (localeCode != null && localeCode != 'system') {
      initialLocale = Locale(localeCode);
    }
    initialThemeCode = AppThemeMode.normalize(
      prefs.getString(PrefsKeys.themeMode),
    );
    initialThemeMode = AppThemeMode.fromCode(initialThemeCode);
  } catch (error) {
    debugPrint('Failed to load initial app preferences: $error');
  }

  await AppThemePlatform.apply(initialThemeCode);

  unawaited(
    FirstOpenAnalytics.reportIfNeeded(baseUrl: statsBaseUrl, version: '1.0.0'),
  );
  runApp(
    Krkr2App(initialLocale: initialLocale, initialThemeMode: initialThemeMode),
  );
}

class Krkr2App extends StatefulWidget {
  const Krkr2App({
    super.key,
    this.initialLocale,
    this.initialThemeMode = ThemeMode.dark,
  });

  final Locale? initialLocale;
  final ThemeMode initialThemeMode;

  /// Change the app locale at runtime. Pass null to follow system default.
  static void setLocale(BuildContext context, Locale? locale) {
    final state = context.findAncestorStateOfType<_Krkr2AppState>();
    state?._setLocale(locale);
  }

  /// Change the app theme mode at runtime.
  static void setThemeMode(BuildContext context, ThemeMode mode) {
    final state = context.findAncestorStateOfType<_Krkr2AppState>();
    state?._setThemeMode(mode);
  }

  @override
  State<Krkr2App> createState() => _Krkr2AppState();
}

class _Krkr2AppState extends State<Krkr2App> {
  late Locale? _locale;
  late ThemeMode _themeMode;
  late final UiThemeController _uiTheme;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
    _themeMode = widget.initialThemeMode;
    _uiTheme = UiThemeController(seed: UiSeedPalette.pink, mode: _themeMode);
  }

  void _setLocale(Locale? locale) {
    setState(() => _locale = locale);
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _uiTheme.updateMode(mode);
  }

  @override
  void dispose() {
    _uiTheme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UiThemeScope(
      controller: _uiTheme,
      child: MaterialApp(
        title: 'KrKr2 Next',
        debugShowCheckedModeBanner: false,
        locale: _locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        themeMode: _themeMode,
        theme: UiTheme.light(seed: _uiTheme.seed),
        darkTheme: UiTheme.dark(seed: _uiTheme.seed),
        home: const HomePage(),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/l10n/app_localizations.dart';
import 'package:flutter_app/pages/manager_page.dart';
import 'package:flutter_app/services/file_manager_controller.dart';
import 'package:flutter_app/services/game_manager.dart';
import 'package:flutter_app/services/manager_scope.dart';
import 'package:flutter_app/services/manager_storage.dart';
import 'package:flutter_app/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory fixture;
  late FileManagerController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fixture = Directory(
      await Directory.systemTemp
          .createTemp('krkr-manager-page-')
          .then((dir) => dir.resolveSymbolicLinks()),
    );
    final root = await Directory(
      p.join(fixture.path, 'Downloads', ManagerScope.ohosAndroidAppId),
    ).create(recursive: true);
    await Directory(p.join(root.path, 'games')).create();
    await File(p.join(root.path, 'games', '中文 🐈.txt')).writeAsString('ok');
    final games = GameManager();
    await games.load();
    controller = FileManagerController(
      gameManager: games,
      storage: ManagerStorage(
        platform: 'linux',
        pickDirectory: () async => root.path,
      ),
    );
    await controller.authorize();
  });

  tearDown(() async {
    controller.dispose();
    if (await fixture.exists()) await fixture.delete(recursive: true);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      UiThemeScope(
        controller: UiThemeController(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: UiTheme.light(),
          home: Scaffold(body: ManagerPage(controller: controller)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists files without a glass row background', (tester) async {
    await pumpPage(tester);
    expect(find.text('Manage'), findsOneWidget);
    expect(find.text('中文 🐈.txt'), findsOneWidget);
    expect(find.byType(UiGlassSurface), findsNothing);
  });

  testWidgets('shows authorization empty state before a grant exists', (
    tester,
  ) async {
    await controller.storage.revoke();
    final empty = FileManagerController(
      gameManager: GameManager(),
      storage: ManagerStorage(
        platform: 'linux',
        pickDirectory: () async => null,
      ),
    );
    await tester.pumpWidget(
      UiThemeScope(
        controller: UiThemeController(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: UiTheme.light(),
          home: Scaffold(body: ManagerPage(controller: empty)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Authorize Folder'), findsOneWidget);
    empty.dispose();
  });

  testWidgets('explains an unsupported platform instead of offering a picker', (
    tester,
  ) async {
    final unsupported = FileManagerController(
      gameManager: GameManager(),
      storage: ManagerStorage(platform: 'android'),
    );
    await tester.pumpWidget(
      UiThemeScope(
        controller: UiThemeController(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: UiTheme.light(),
          home: Scaffold(body: ManagerPage(controller: unsupported)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Authorize Folder'), findsNothing);
    // Shown inline exactly once: the load error must not also toast it.
    expect(
      find.text('Folder access is not available on this platform yet.'),
      findsOneWidget,
    );
    unsupported.dispose();
  });
}

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

  // Widget tests run inside FakeAsync, where dart:io futures never resolve on
  // their own. Disk setup done in a test body therefore goes through
  // [tester.runAsync]; IO started by the UI (a refresh, a folder walk) only
  // advances when the fake microtask queue is flushed, which [settleIo] does
  // one round trip at a time until [until] shows up.
  Future<void> io(WidgetTester tester, Future<void> Function() work) =>
      tester.runAsync(work);

  Future<void> settleIo(WidgetTester tester, Finder until) async {
    for (var i = 0; i < 200 && until.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(until, findsOneWidget);
    await tester.pumpAndSettle();
  }

  /// Location shown in the details sheet: breadcrumb root plus folders.
  String location(String path) => controller.locationOf(path);

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

  testWidgets('system back leaves selection, then walks up, then yields', (
    tester,
  ) async {
    final gamesPath = controller.files!.gamesPath;
    await io(tester, () async {
      await Directory(p.join(gamesPath, 'sub')).create();
      await controller.open(p.join(gamesPath, 'sub'));
    });
    controller.toggleSelecting(true);
    await pumpPage(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    // Back is handled inside the tab; goBack() then lists the parent, which
    // is real IO, so the pop is issued where that IO can complete.
    Future<void> back({required bool handled}) => io(tester, () async {
      expect(await navigator.maybePop(), handled);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    await back(handled: true);
    await tester.pumpAndSettle();
    expect(controller.selecting, isFalse);
    expect(controller.currentPath, p.join(gamesPath, 'sub'));

    await back(handled: true);
    await tester.pumpAndSettle();
    expect(controller.currentPath, gamesPath);

    await back(handled: true);
    await tester.pumpAndSettle();
    expect(controller.currentPath, controller.files!.rootPath);

    // At the authorized root the tab no longer claims back.
    await back(handled: false);
  });

  testWidgets('an inactive tab never intercepts back', (tester) async {
    final gamesPath = controller.files!.gamesPath;
    await io(tester, () async {
      await Directory(p.join(gamesPath, 'sub')).create();
      await controller.open(p.join(gamesPath, 'sub'));
    });
    await tester.pumpWidget(
      UiThemeScope(
        controller: UiThemeController(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: UiTheme.light(),
          home: Scaffold(
            body: ManagerPage(controller: controller, active: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(await navigator.maybePop(), isFalse);
    expect(controller.currentPath, p.join(gamesPath, 'sub'));
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

  testWidgets('tapping a file opens its details', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('中文 🐈.txt'));
    await tester.pumpAndSettle();

    // The list row shows the size too, so look inside the sheet only.
    final sheet = find.byType(UiListSection);
    expect(sheet, findsOneWidget);
    Finder inSheet(String text) =>
        find.descendant(of: sheet, matching: find.text(text));
    expect(inSheet('Kind'), findsOneWidget);
    expect(inSheet('File'), findsOneWidget);
    expect(inSheet('2 B'), findsOneWidget);
    expect(inSheet('Modified'), findsOneWidget);
    // Anchored at the breadcrumb root, never the temp dir the fixture lives in.
    final gamesPath = controller.files!.gamesPath;
    expect(location(gamesPath), 'Download/${ManagerScope.ohosAndroidAppId}');
    expect(find.text('${location(gamesPath)}/games'), findsOneWidget);
    expect(find.textContaining(fixture.path), findsNothing);
  });

  testWidgets('folder details total the contents after opening', (
    tester,
  ) async {
    final gamesPath = controller.files!.gamesPath;
    await io(tester, () async {
      final file = await File(
        p.join(gamesPath, 'pack', 'a.bin'),
      ).create(recursive: true);
      await file.writeAsBytes(List.filled(3, 0));
      await controller.refresh();
    });
    await pumpPage(tester);

    await tester.longPress(find.text('pack'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    // The sheet opens at once and fills the total in once the walk is done.
    expect(find.text('Folder'), findsOneWidget);
    expect(find.text('Calculating…'), findsOneWidget);
    await settleIo(tester, find.text('3 B · 1 items'));
    expect(find.text('Calculating…'), findsNothing);
  });

  testWidgets('a protected folder still offers details, nothing else', (
    tester,
  ) async {
    await io(tester, () => controller.openBreadcrumb(0));
    await pumpPage(tester);

    await tester.longPress(find.text('games'));
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Rename'), findsNothing);
    expect(find.text('Move to Recently Deleted'), findsNothing);
  });

  // Drags past the trigger distance and lets the refresh run to completion:
  // the listing IO, the success hold and the indicator collapsing again.
  Future<void> pullToRefresh(WidgetTester tester, Finder appears) async {
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await settleIo(tester, appears);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Refreshing'), findsNothing);
  }

  testWidgets('pulling down reloads the listing', (tester) async {
    await pumpPage(tester);
    final gamesPath = controller.files!.gamesPath;
    await io(
      tester,
      () => File(p.join(gamesPath, 'late.txt')).writeAsString('x'),
    );
    expect(find.text('late.txt'), findsNothing);

    await pullToRefresh(tester, find.text('late.txt'));
  });

  testWidgets('an empty folder can still be pulled to refresh', (tester) async {
    final gamesPath = controller.files!.gamesPath;
    final empty = Directory(p.join(gamesPath, 'empty'));
    await io(tester, () async {
      await empty.create();
      await controller.open(empty.path);
    });
    await pumpPage(tester);
    expect(find.text('This folder is empty'), findsOneWidget);

    await io(
      tester,
      () => File(p.join(empty.path, 'new.txt')).writeAsString('x'),
    );
    await pullToRefresh(tester, find.text('new.txt'));
    expect(find.text('This folder is empty'), findsNothing);
  });
}

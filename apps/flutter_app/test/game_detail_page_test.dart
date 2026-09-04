import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/l10n/app_localizations.dart';
import 'package:flutter_app/models/game_info.dart';
import 'package:flutter_app/pages/game_detail_page.dart';
import 'package:flutter_app/services/game_manager.dart';
import 'package:flutter_app/ui/ui.dart';

void main() {
  testWidgets('detail toolbar collapses and expands with page scroll', (
    WidgetTester tester,
  ) async {
    final game = GameInfo(
      path: '/games/test-game',
      title: '测试游戏',
      developer: '测试开发者',
      description: List<String>.filled(20, '游戏简介内容').join('，'),
      keywords: List<String>.generate(12, (index) => '关键词 $index'),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: UiTheme.dark(),
        home: GameDetailPage(game: game, gameManager: GameManager()),
      ),
    );
    await tester.pumpAndSettle();

    const titleKey = ValueKey<String>('game-detail-toolbar-title');
    const launchKey = ValueKey<String>('game-detail-toolbar-launch');
    final initialTitle = tester.widget<Opacity>(find.byKey(titleKey));
    final initialLaunchWidth = tester.getSize(find.byKey(launchKey)).width;
    final initialBar = tester.widget<AppBar>(find.byType(AppBar));

    expect(initialTitle.opacity, 0);
    expect(initialBar.backgroundColor?.a, 0);
    expect(initialLaunchWidth, greaterThan(32));

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();

    final collapsedTitle = tester.widget<Opacity>(find.byKey(titleKey));
    final collapsedLaunchWidth = tester.getSize(find.byKey(launchKey)).width;
    final collapsedBar = tester.widget<AppBar>(find.byType(AppBar));

    expect(collapsedTitle.opacity, closeTo(1, 0.001));
    expect(collapsedBar.backgroundColor?.a, closeTo(1, 0.001));
    expect(collapsedLaunchWidth, closeTo(32, 0.001));

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();

    final expandedTitle = tester.widget<Opacity>(find.byKey(titleKey));
    final expandedLaunchWidth = tester.getSize(find.byKey(launchKey)).width;
    final expandedBar = tester.widget<AppBar>(find.byType(AppBar));

    expect(expandedTitle.opacity, 0);
    expect(expandedBar.backgroundColor?.a, 0);
    expect(expandedLaunchWidth, closeTo(initialLaunchWidth, 0.001));
  });
}

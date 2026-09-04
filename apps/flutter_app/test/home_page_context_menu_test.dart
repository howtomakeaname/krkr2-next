import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/l10n/app_localizations.dart';
import 'package:flutter_app/models/game_engine.dart';
import 'package:flutter_app/models/game_info.dart';
import 'package:flutter_app/pages/game_detail_page.dart';
import 'package:flutter_app/pages/home_page.dart';
import 'package:flutter_app/ui/ui.dart';

void main() {
  testWidgets('home shell paints immediately without a full-screen loader', (
    WidgetTester tester,
  ) async {
    final game = GameInfo(
      path: '/games/test-game',
      title: '测试游戏',
      engine: GameEngine.krkr2,
    );
    SharedPreferences.setMockInitialValues({
      'krkr2_game_list': GameInfo.listToJsonString([game]),
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: UiTheme.dark(),
        home: const HomePage(),
      ),
    );

    expect(find.text('KrKr2 Next'), findsOneWidget);
    expect(find.byType(UiLoader), findsNothing);
    expect(find.byType(UiSkeleton), findsWidgets);

    await tester.pumpAndSettle();
    expect(find.text('测试游戏'), findsOneWidget);
  });

  testWidgets('game context menu starts with launch and omits XP3 packing', (
    WidgetTester tester,
  ) async {
    final game = GameInfo(
      path: '/games/test-game',
      title: '测试游戏',
      engine: GameEngine.krkr2,
    );
    SharedPreferences.setMockInitialValues({
      'krkr2_game_list': GameInfo.listToJsonString([game]),
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: UiTheme.dark(),
        home: const HomePage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('测试游戏'));
    await tester.pumpAndSettle();

    final menuLabels = <String>['启动游戏', '刮削信息', '重命名', '移除'];
    for (final label in menuLabels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('设置封面'), findsNothing);
    expect(find.text('打包为 XP3'), findsNothing);

    final launchTop = tester.getTopLeft(find.text('启动游戏')).dy;
    for (final label in menuLabels.skip(1)) {
      expect(launchTop, lessThan(tester.getTopLeft(find.text(label)).dy));
    }

    await tester.tap(find.text('移除'));
    await tester.pumpAndSettle();

    expect(find.text('移除游戏'), findsOneWidget);
    expect(find.text('启动游戏'), findsNothing);
    expect(find.text('刮削信息'), findsNothing);
    expect(find.text('重命名'), findsNothing);

    await tester.tap(find.text('移除'));
    await tester.pumpAndSettle();

    expect(find.text('测试游戏'), findsNothing);
    expect(find.text('启动游戏'), findsNothing);
  });

  testWidgets('home scrape opens keyword dialog without entering detail page', (
    WidgetTester tester,
  ) async {
    final game = GameInfo(
      path: '/games/test-game',
      title: '测试游戏',
      engine: GameEngine.krkr2,
    );
    SharedPreferences.setMockInitialValues({
      'krkr2_game_list': GameInfo.listToJsonString([game]),
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: UiTheme.dark(),
        home: const HomePage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('测试游戏'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刮削信息'));
    await tester.pumpAndSettle();

    expect(find.text('刮削信息'), findsOneWidget);
    expect(find.byType(GameDetailPage), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
  });
}

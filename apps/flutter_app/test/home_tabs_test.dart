import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/l10n/app_localizations.dart';
import 'package:flutter_app/models/game_engine.dart';
import 'package:flutter_app/models/game_info.dart';
import 'package:flutter_app/pages/home_page.dart';
import 'package:flutter_app/ui/ui.dart';

void main() {
  testWidgets('profile tab shows play stats and support destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final game = GameInfo(
      path: '/games/test-game',
      title: '测试游戏',
      engine: GameEngine.krkr2,
      lastPlayed: DateTime(2026, 9, 4),
      playDurationSeconds: 2 * 3600 + 5 * 60,
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

    await tester.tap(find.byKey(const ValueKey('ui-nav-item-3')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-play-card')), findsOneWidget);
    expect(find.text('游玩时间'), findsOneWidget);
    expect(find.text('2 小时 5 分钟'), findsOneWidget);
    expect(find.text('游戏记录'), findsOneWidget);
    expect(find.text('最近游玩'), findsOneWidget);
    expect(find.text('测试游戏'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('帮助'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);

    await tester.tap(find.text('帮助'));
    await tester.pumpAndSettle();
    expect(find.text('导入游戏'), findsOneWidget);
    expect(find.text('启动与快捷操作'), findsOneWidget);
  });

  testWidgets('tab selection lens follows the selected destination', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
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

    final lens = find.byKey(const ValueKey('ui-nav-selection-lens'));
    final glass = find.byKey(const ValueKey('ui-nav-glass'));
    expect(tester.getSize(glass).width, 286);
    expect(tester.getSize(lens).width, lessThan(286 / 4));
    final homeLeft = tester.getTopLeft(lens).dx;
    await tester.tap(find.byKey(const ValueKey('ui-nav-item-2')));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(lens).dx, greaterThan(homeLeft));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/l10n/app_localizations.dart';
import 'package:flutter_app/models/play_insights.dart';
import 'package:flutter_app/widgets/play_honor_card.dart';
import 'package:flutter_app/ui/ui.dart';

void main() {
  testWidgets('honor keeps future titles out of text and accessibility', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: UiTheme.light(),
        home: Scaffold(
          body: PlayHonorCard(
            honor: PlayHonor.from(
              lifetimeSeconds: 5 * 3600,
              playedGameCount: 1,
            ),
            remainingDuration: '5 小时',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('statistics-honor-card'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    expect(find.text('剧情旅人'), findsOneWidget);
    expect(find.text('还差 5 小时和 2 款游戏'), findsOneWidget);
    for (final hidden in ['沉浸读者', '资深玩家', '游戏藏家', '典藏家']) {
      expect(find.textContaining(hidden), findsNothing);
      expect(find.bySemanticsLabel(RegExp(hidden)), findsNothing);
    }
    final progress = find.descendant(
      of: card,
      matching: find.byType(LinearProgressIndicator),
    );
    expect(
      tester.widget<LinearProgressIndicator>(progress).value,
      greaterThan(0),
    );
    expect(tester.getSize(progress).height, greaterThan(0));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  for (final highest in [false, true]) {
    testWidgets(
      'honor handles large text and ${highest ? 'highest tier' : 'empty history'}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: UiTheme.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(1.6),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  PlayHonorCard(
                    honor: PlayHonor.from(
                      lifetimeSeconds: highest ? 360 * 3600 : 0,
                      playedGameCount: highest ? 24 : 0,
                    ),
                    remainingDuration: '1 hour',
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final card = find.byKey(const ValueKey('statistics-honor-card'));
        await tester.scrollUntilVisible(
          card,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final progress = find.descendant(
          of: card,
          matching: find.byType(LinearProgressIndicator),
        );
        if (highest) {
          expect(progress, findsNothing);
          expect(find.text('Next title'), findsNothing);
        } else {
          expect(tester.widget<LinearProgressIndicator>(progress).value, 0);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

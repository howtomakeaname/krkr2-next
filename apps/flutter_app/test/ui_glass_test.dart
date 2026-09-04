import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter_app/ui/ui.dart';

void main() {
  testWidgets('glass surface can disable realtime blur', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.dark(),
        home: const UiGlassSurface(
          enableBlur: false,
          child: SizedBox(width: 80, height: 44),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(UiGlassSurface), findsOneWidget);
  });

  testWidgets('glass icon button keeps a 44 point target and dispatches taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.light(),
        home: Center(
          child: UiGlassIconButton(
            icon: LucideIcons.plus,
            semanticLabel: 'Add game',
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(UiGlassIconButton)),
      const Size.square(UiNavigationMetrics.buttonExtent),
    );
    expect(find.bySemanticsLabel('Add game'), findsOneWidget);

    await tester.tap(find.byType(UiGlassIconButton));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('standalone glass optics follow a drag and spring home', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.dark(),
        home: Center(
          child: UiGlassIconButton(
            icon: LucideIcons.plus,
            semanticLabel: 'Add game',
            onPressed: () {},
          ),
        ),
      ),
    );

    double orbTranslationX() {
      final transform = tester.widget<Transform>(
        find.byKey(const ValueKey<String>('ui-glass-orb')),
      );
      return transform.transform.getTranslation().x;
    }

    final resting = orbTranslationX();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(UiGlassIconButton)),
    );
    await tester.pump(const Duration(milliseconds: 90));
    await gesture.moveBy(const Offset(17, 0));
    await tester.pump(const Duration(milliseconds: 80));

    final pulled = orbTranslationX();
    expect(pulled, greaterThan(resting + 0.5));

    await gesture.up();
    await tester.pumpAndSettle();
    final settled = orbTranslationX();
    expect(settled, closeTo(resting, 0.05));
  });
}

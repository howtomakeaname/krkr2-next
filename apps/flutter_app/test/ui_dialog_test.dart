import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/ui/ui.dart';

void main() {
  testWidgets('dialog samples the backdrop only after its motion settles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.light(),
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () {
                UiDialog.show<void>(
                  context,
                  title: 'Remove game',
                  message: 'This keeps the files on disk.',
                  actions: const [UiDialogAction(label: 'Cancel')],
                );
              },
              child: const Text('Show dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show dialog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final surfaceFinder = find.byKey(
      const ValueKey<String>('ui-dialog-surface'),
    );
    var surface = tester.widget<UiGlassSurface>(surfaceFinder);
    expect(surface.enableBlur, isFalse);
    expect(surface.showRefraction, isFalse);
    expect(surface.blurScale, 0.12);
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.pumpAndSettle();

    surface = tester.widget<UiGlassSurface>(surfaceFinder);
    expect(surface.enableBlur, isTrue);
    expect(surface.showRefraction, isTrue);
    expect(find.byType(BackdropFilter), findsWidgets);

    final route = ModalRoute.of(tester.element(find.text('Remove game')))!;
    expect(route.reverseTransitionDuration, UiSprings.dismissDuration);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    surface = tester.widget<UiGlassSurface>(surfaceFinder);
    expect(surface.enableBlur, isFalse);
    expect(surface.showRefraction, isFalse);
    expect(find.byType(BackdropFilter), findsNothing);
    final closingOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey<String>('ui-dialog-motion-opacity')),
    );
    expect(closingOpacity.opacity, lessThan(1));
    expect(closingOpacity.opacity, greaterThan(0));

    await tester.pumpAndSettle();
    expect(surfaceFinder, findsNothing);
  });
}

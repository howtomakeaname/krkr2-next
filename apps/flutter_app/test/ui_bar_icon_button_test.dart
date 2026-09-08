import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:flutter_app/ui/ui.dart';

void main() {
  testWidgets('bar icon button uses the shared navigation dimensions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.light(),
        home: Scaffold(
          appBar: AppBar(
            leading: const UiBarIconButton(
              icon: LucideIcons.arrowLeft,
              semanticLabel: 'Back',
            ),
          ),
        ),
      ),
    );

    final button = find.descendant(
      of: find.byType(UiBarIconButton),
      matching: find.byType(UiGlassIconButton),
    );
    final icon = tester.widget<Icon>(find.byIcon(LucideIcons.arrowLeft));

    expect(tester.getSize(button), const Size.square(UiBarIconButton.extent));
    expect(icon.size, UiBarIconButton.iconSize);
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
  });

  testWidgets('pressed glass stays within the existing app bar height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.dark(),
        home: Scaffold(
          appBar: AppBar(
            leading: UiBarIconButton(
              icon: LucideIcons.arrowLeft,
              semanticLabel: 'Back',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    final button = find.byType(UiGlassIconButton);
    final appBarBounds = tester.getRect(find.byType(AppBar));
    final glass = tester.renderObject<RenderBox>(find.byType(AdaptiveGlass));
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveBy(const Offset(45, 12));
    await tester.pump(const Duration(milliseconds: 160));
    final pressed = Rect.fromPoints(
      glass.localToGlobal(Offset.zero),
      glass.localToGlobal(glass.size.bottomRight(Offset.zero)),
    );
    expect(pressed.width, greaterThan(44));
    expect(pressed.width, lessThan(52));
    expect(pressed.top, greaterThanOrEqualTo(appBarBounds.top));
    expect(pressed.bottom, lessThanOrEqualTo(appBarBounds.bottom));
    expect(pressed.left, greaterThanOrEqualTo(appBarBounds.left));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.getSize(button), const Size.square(44));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      matching: find.byType(AnimatedContainer),
    );
    final icon = tester.widget<Icon>(find.byIcon(LucideIcons.arrowLeft));

    expect(tester.getSize(button), const Size.square(UiBarIconButton.extent));
    expect(icon.size, UiBarIconButton.iconSize);
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
  });
}

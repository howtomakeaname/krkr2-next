import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('home shell exposes the four primary tabs', (tester) async {
    await tester.pumpWidget(const Krkr2App());
    await tester.pumpAndSettle();

    expect(find.text('KrKr2 Next'), findsOneWidget);
    expect(find.byKey(const ValueKey('ui-nav-item-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('ui-nav-item-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('ui-nav-item-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('ui-nav-item-3')), findsOneWidget);
  });

  testWidgets('home empty state renders without a floating action button', (
    tester,
  ) async {
    await tester.pumpWidget(const Krkr2App());
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('No games added yet'), findsOneWidget);
  });
}

import 'dart:ui' show SemanticsAction, SemanticsActionEvent, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:flutter_app/ui/ui.dart';

const _items = [
  UiNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: '库'),
  UiNavItem(icon: Icons.explore_outlined, label: '探索'),
  UiNavItem(icon: Icons.folder_outlined, label: '管理'),
  UiNavItem(icon: Icons.person_outline, label: '我的'),
];

Finder _item(int index) => find.byKey(ValueKey('ui-nav-item-$index'));

Future<void> _pumpBar(
  WidgetTester tester, {
  required ValueChanged<int> onChanged,
  Brightness brightness = Brightness.light,
  double width = 390,
  double textScale = 1,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var selected = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark ? UiTheme.dark() : UiTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 844),
          padding: const EdgeInsets.only(bottom: 34),
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
        ),
        child: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            extendBody: true,
            body: const ColoredBox(color: Colors.blueGrey),
            bottomNavigationBar: UiNavBar(
              items: _items,
              currentIndex: selected,
              onChanged: (index) {
                setState(() => selected = index);
                onChanged(index);
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('taps select once and preserve selection semantics', (
    tester,
  ) async {
    final selections = <int>[];
    await _pumpBar(tester, onChanged: selections.add);

    for (final index in [1, 2, 3, 0]) {
      await tester.tapAt(tester.getCenter(_item(index)));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(_item(index)).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(find.bySemanticsLabel(_items[index].label), findsOneWidget);
    }
    expect(selections, [1, 2, 3, 0]);
    await tester.tapAt(tester.getCenter(_item(0)));
    await tester.pumpAndSettle();
    expect(selections, [1, 2, 3, 0]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'drag selects a destination without a pointer overlay blocking it',
    (tester) async {
      final selections = <int>[];
      await _pumpBar(tester, onChanged: selections.add);
      final gesture = await tester.startGesture(tester.getCenter(_item(0)));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(tester.getCenter(_item(3)));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selections.last, 3);
      expect(
        tester.widget<GlassTabBar>(find.byType(GlassTabBar)).selectedIndex,
        3,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('screen reader and keyboard can activate destinations', (
    tester,
  ) async {
    final selections = <int>[];
    await _pumpBar(tester, onChanged: selections.add);
    final node = tester.getSemantics(_item(2));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(
        type: SemanticsAction.tap,
        nodeId: node.id,
        viewId: tester.view.viewId,
      ),
    );
    await tester.pumpAndSettle();
    expect(selections, [2]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selections.last, 0);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'fits narrow ${brightness.name} layout and respects reduced motion',
      (tester) async {
        await _pumpBar(
          tester,
          onChanged: (_) {},
          width: 320,
          textScale: 2,
          brightness: brightness,
          reduceMotion: true,
        );
        final rect = tester.getRect(find.byKey(const ValueKey('ui-nav-glass')));
        expect(rect.width, 280);
        expect(rect.bottom, 810);
        // MediaQuery keeps the OS light; app dark mode must still be legible.
        final iconContext = tester.element(
          find.byIcon(Icons.person_outline).first,
        );
        final labelColor = IconTheme.of(iconContext).color!;
        final bar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
        expect(
          bar.selectedIconColor,
          Theme.of(iconContext).colorScheme.primary,
        );
        expect(bar.selectedLabelColor, bar.selectedIconColor);
        expect(bar.unselectedIconColor, isNot(bar.selectedIconColor));
        expect(
          labelColor.computeLuminance(),
          brightness == Brightness.dark ? greaterThan(0.5) : lessThan(0.5),
        );
        for (var index = 0; index < 4; index++) {
          expect(tester.getSize(_item(index)).width, greaterThanOrEqualTo(44));
        }
        expect(
          tester
              .widget<GlassTabBar>(find.byType(GlassTabBar))
              .interactionBehavior,
          GlassInteractionBehavior.none,
        );
        await tester.tapAt(tester.getCenter(_item(3)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

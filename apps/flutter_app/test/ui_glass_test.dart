import 'dart:ui' show SemanticsAction, SemanticsActionEvent;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
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

    Rect glassBounds() {
      final box = tester.renderObject<RenderBox>(find.byType(AdaptiveGlass));
      return Rect.fromPoints(
        box.localToGlobal(Offset.zero),
        box.localToGlobal(box.size.bottomRight(Offset.zero)),
      );
    }

    final resting = glassBounds();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(UiGlassIconButton)),
    );
    await tester.pump(const Duration(milliseconds: 90));
    await gesture.moveBy(const Offset(17, 0));
    await tester.pump(const Duration(milliseconds: 80));

    final pulled = glassBounds();
    expect(pulled.width, greaterThan(resting.width + 0.5));
    expect(pulled.center.dx, greaterThan(resting.center.dx));

    await gesture.up();
    await tester.pumpAndSettle();
    final settled = glassBounds();
    expect(settled.width, closeTo(resting.width, 0.05));
    expect(settled.center.dx, closeTo(resting.center.dx, 0.05));
  });

  testWidgets('long press does not also activate the glass button', (
    tester,
  ) async {
    var taps = 0;
    var holds = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.light(),
        home: Center(
          child: UiGlassIconButton(
            icon: LucideIcons.plus,
            semanticLabel: 'Add',
            enableHaptic: false,
            onPressed: () => taps++,
            onLongPress: () => holds++,
          ),
        ),
      ),
    );
    await tester.longPress(find.byType(UiGlassIconButton));
    await tester.pumpAndSettle();
    expect(holds, 1);
    expect(taps, 0);
    await tester.tap(find.byType(UiGlassIconButton));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('loading cancels a held press and disables activation', (
    tester,
  ) async {
    var taps = 0;
    var loading = false;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.light(),
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Center(
              child: UiGlassIconButton(
                icon: LucideIcons.plus,
                semanticLabel: 'Add',
                loading: loading,
                onPressed: () => taps++,
              ),
            );
          },
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(UiGlassIconButton)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    rebuild(() => loading = true);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final semantics = tester.getSemantics(find.byType(UiGlassIconButton));
    expect(
      semantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isFalse,
    );
    rebuild(() => loading = false);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(UiGlassIconButton));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('glass button supports keyboard and semantic activation once', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.light(),
        home: Center(
          child: UiGlassIconButton(
            icon: LucideIcons.plus,
            semanticLabel: 'Add',
            enableHaptic: false,
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.bySemanticsLabel('Add'), findsOneWidget);
    final node = tester.getSemantics(find.bySemanticsLabel('Add'));
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(
        type: SemanticsAction.tap,
        nodeId: node.id,
        viewId: tester.view.viewId,
      ),
    );
    await tester.pumpAndSettle();
    expect(taps, 2);
  });

  testWidgets('shared toolbar has one glass surface and separate actions', (
    tester,
  ) async {
    var searches = 0;
    var imports = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.light(),
        home: Center(
          child: UiGlassToolbar(
            children: [
              UiGlassIconButton(
                icon: LucideIcons.search,
                semanticLabel: 'Search',
                contained: false,
                onPressed: () => searches++,
              ),
              UiGlassIconButton(
                icon: LucideIcons.plus,
                semanticLabel: 'Import',
                contained: false,
                onPressed: () => imports++,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(AdaptiveGlass), findsOneWidget);
    expect(find.byType(UiGlassSurface), findsNothing);
    expect(tester.getSize(find.byType(UiGlassToolbar)), const Size(92, 48));
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Import'));
    await tester.pumpAndSettle();
    expect(searches, 1);
    expect(imports, 1);
  });

  testWidgets('disabled glass button has no press or long-press action', (
    tester,
  ) async {
    var holds = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.light(),
        home: Center(
          child: UiGlassIconButton(
            icon: LucideIcons.plus,
            semanticLabel: 'Add',
            onLongPress: () => holds++,
          ),
        ),
      ),
    );
    await tester.longPress(find.byType(UiGlassIconButton), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(holds, 0);
    final data = tester
        .getSemantics(find.byType(UiGlassIconButton))
        .getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    expect(data.hasAction(SemanticsAction.longPress), isFalse);
  });

  testWidgets('reduced motion keeps glass stationary while dragging', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.dark(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Center(
            child: UiGlassIconButton(
              icon: LucideIcons.plus,
              semanticLabel: 'Add',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    final box = tester.renderObject<RenderBox>(find.byType(AdaptiveGlass));
    final resting = box.getTransformTo(null);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(UiGlassIconButton)),
    );
    await gesture.moveBy(const Offset(30, 10));
    await tester.pump(const Duration(milliseconds: 150));
    expect(box.getTransformTo(null), resting);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('explicit blur opt-out avoids shader and backdrop filters', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.dark(),
        home: Center(
          child: UiGlassIconButton(
            icon: LucideIcons.plus,
            semanticLabel: 'Add',
            enableBlur: false,
            onPressed: () {},
          ),
        ),
      ),
    );
    expect(
      tester.widget<GlassButton>(find.byType(GlassButton)).quality,
      GlassQuality.minimal,
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('button follows app appearance and keeps its theme accent', (
    tester,
  ) async {
    final theme = UiTheme.dark();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: const MediaQueryData(platformBrightness: Brightness.light),
          child: Center(
            child: UiGlassIconButton(
              icon: LucideIcons.plus,
              semanticLabel: 'Add',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    final buttonContext = tester.element(find.byType(GlassButton));
    expect(GlassTheme.brightnessOf(buttonContext), Brightness.dark);
    expect(
      tester.widget<Icon>(find.byIcon(LucideIcons.plus)).color,
      buttonContext.uiColors.brand,
    );
  });
}

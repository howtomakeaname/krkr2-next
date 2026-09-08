import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/engine/engine_bridge.dart';
import 'package:flutter_app/engine/virtual_input_controller.dart';
import 'package:flutter_app/l10n/app_localizations.dart';
import 'package:flutter_app/ui/ui.dart';
import 'package:flutter_app/widgets/virtual_game_controls.dart';

void main() {
  late List<EngineInputEventData> events;
  late VirtualInputController input;
  var initialized = false;
  setUp(() {
    events = [];
    initialized = false;
  });
  void createInput() {
    input = VirtualInputController(
      send: (event) async {
        events.add(event);
      },
      onError: (error) => fail('$error'),
    );
    initialized = true;
  }

  tearDown(() => input.dispose());

  Future<void> mount(
    WidgetTester tester, {
    bool show = true,
    bool enabled = true,
    VoidCallback? canvasTap,
    Size size = const Size(800, 400),
    Locale locale = const Locale('en'),
  }) async {
    if (!initialized) createInput();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.dark(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => canvasTap?.call(),
                child: const SizedBox.expand(),
              ),
              if (show)
                VirtualGameControls(controller: input, enabled: enabled),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'multi-touch keys and dragging do not click the underlying game',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var taps = 0;
      await mount(tester, canvasTap: () => taps++);
      final up = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('virtual-key-38'))),
        pointer: 1,
      );
      final mouse = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('virtual-mouse-0'))),
        pointer: 2,
      );
      final pad = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('virtual-touchpad'))),
        pointer: 3,
      );
      await pad.moveBy(const Offset(-24, -12));
      await pad.up();
      await mouse.up();
      await up.cancel();
      await tester.pump();
      await input.drained;
      expect(taps, 0);
      expect(events.map((e) => e.type), [5, 1, 2, 3, 6]);
      expect(events[2].x, 340);
      expect(events[2].y, 170);
      expect(events[3].x, 340);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('hiding and backgrounding release held keys and mouse buttons', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester);
    final control = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('virtual-key-17'))),
      pointer: 1,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await input.drained;
    expect(events.map((e) => e.type), [5, 6]);
    await control.up();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    final mouse = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('virtual-mouse-1'))),
      pointer: 2,
    );
    await mount(tester, show: false);
    await input.drained;
    expect(events.skip(2).map((e) => (e.type, e.button)), [(1, 1), (3, 1)]);
    await mouse.up();
    expect(input.enabled, false);
  });

  testWidgets('touchpad tap clicks cursor and compact localized layouts fit', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final locale in [
      const Locale('en'),
      const Locale('zh'),
      const Locale('ja'),
    ]) {
      await mount(tester, size: const Size(320, 568), locale: locale);
      expect(tester.takeException(), isNull);
      final left = tester.getRect(find.byKey(const ValueKey('virtual-key-39')));
      final right = tester.getRect(
        find.byKey(const ValueKey('virtual-mouse-0')),
      );
      expect(left.right, lessThanOrEqualTo(right.left));
    }
    await tester.tap(find.byKey(const ValueKey('virtual-touchpad')));
    await input.drained;
    expect(events.map((e) => (e.type, e.x, e.y)), [
      (1, 160.0, 284.0),
      (3, 160.0, 284.0),
    ]);
  });
}

import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/engine/engine_bridge.dart';
import 'package:flutter_app/engine/virtual_input_controller.dart';

void main() {
  late List<EngineInputEventData> events;
  late VirtualInputController input;
  setUp(() {
    events = [];
    input = VirtualInputController(
      send: (event) async {
        events.add(event);
      },
      onError: (error) => fail('$error'),
    );
    input.setViewport(const Size(800, 400));
    input.setEnabled(true);
  });
  tearDown(() => input.dispose());

  test(
    'shared key ownership and disabling release all held inputs once',
    () async {
      input.setKeys('one', {GameVirtualKey.control, GameVirtualKey.up});
      input.setKeys('two', {GameVirtualKey.up});
      input.pressMouse('mouse', 1);
      input.release('one');
      await input.drained;
      expect(
        events
            .where((e) => e.type == EngineInputEventType.keyUp)
            .map((e) => e.keyCode),
        [GameVirtualKey.control],
      );
      expect(events.first.modifiers & 4, 4);
      await input.setEnabled(false);
      input.release('two');
      input.release('mouse');
      input.setKeys('ignored', {GameVirtualKey.enter});
      await input.drained;
      expect(
        events
            .where((e) => e.type == EngineInputEventType.keyUp)
            .map((e) => e.keyCode),
        [GameVirtualKey.control, GameVirtualKey.up],
      );
      expect(
        events
            .where((e) => e.type == EngineInputEventType.pointerUp)
            .map((e) => e.button),
        [1],
      );
      expect(events.length, 6);
    },
  );

  test(
    'cursor drag uses virtual coordinates and clamps at viewport edges',
    () async {
      input.pressMouse('left', 0);
      input.moveCursor(const Offset(100, -50));
      input.release('left');
      await input.drained;
      expect(events.map((e) => e.type), [1, 2, 3]);
      expect(Offset(events[1].x, events[1].y), const Offset(500, 150));
      expect(events[1].modifiers & 8, 8);
      expect(events.last.x, 500);
      input.moveCursor(const Offset(5000, -5000));
      await input.drained;
      expect(input.cursor.value, const Offset(799, 0));
      input.setViewport(const Size(400, 800));
      expect(input.cursor.value, const Offset(399, 0));
    },
  );

  test('release waits for an in-flight press before being sent', () async {
    input.dispose();
    final gate = Completer<void>();
    input = VirtualInputController(
      send: (event) async {
        events.add(event);
        if (event.type == EngineInputEventType.keyDown) await gate.future;
      },
      onError: (error) => fail('$error'),
    );
    input.setEnabled(true);
    input.setKeys('one', {GameVirtualKey.enter});
    var released = false;
    final done = input.setEnabled(false).then((_) => released = true);
    await Future<void>.delayed(Duration.zero);
    expect(events.map((e) => e.type), [5]);
    expect(released, false);
    gate.complete();
    await done;
    expect(events.map((e) => e.type), [5, 6]);
  });
}

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'engine_bridge.dart';

/// The native KiriKiri input API uses Windows virtual key codes.
abstract final class GameVirtualKey {
  static const enter = 0x0d;
  static const escape = 0x1b;
  static const space = 0x20;
  static const control = 0x11;
  static const left = 0x25;
  static const up = 0x26;
  static const right = 0x27;
  static const down = 0x28;
}

/// Owns only synthetic input. Each touch has an owner, so lifting one finger
/// cannot release a key or mouse button still held by another finger.
class VirtualInputController {
  VirtualInputController({required this.send, required this.onError});

  final Future<void> Function(EngineInputEventData) send;
  final ValueChanged<Object> onError;
  final cursor = ValueNotifier<Offset>(Offset.zero);
  final Stopwatch _clock = Stopwatch()..start();
  final Map<Object, Set<int>> _keys = {};
  final Map<Object, int> _buttons = {};
  Size _viewport = Size.zero;
  Future<void> _pending = Future<void>.value();
  bool _enabled = false;

  Future<void> get drained => _pending;
  bool get enabled => _enabled;
  Set<int> get _heldKeys => _keys.values.expand((keys) => keys).toSet();
  int get _modifiers =>
      (_heldKeys.contains(GameVirtualKey.control) ? 4 : 0) |
      (_buttons.containsValue(0) ? 8 : 0) |
      (_buttons.containsValue(1) ? 16 : 0);

  Future<void> setEnabled(bool value) {
    _enabled = value;
    return value ? _pending : releaseAll();
  }

  void setViewport(Size size) {
    if (size == _viewport || size.isEmpty || !size.isFinite) return;
    final next = _viewport.isEmpty
        ? size.center(Offset.zero)
        : Offset(
            cursor.value.dx / _viewport.width * size.width,
            cursor.value.dy / _viewport.height * size.height,
          );
    _viewport = size;
    cursor.value = _clamp(next);
  }

  Offset _clamp(Offset point) => Offset(
    point.dx.clamp(0.0, (_viewport.width - 1).clamp(0.0, double.infinity)),
    point.dy.clamp(0.0, (_viewport.height - 1).clamp(0.0, double.infinity)),
  );

  // Keep the visible cursor aligned with direct touch/physical mouse input.
  void syncCursor(Offset position) {
    if (!_viewport.isEmpty) cursor.value = _clamp(position);
  }

  void moveCursor(Offset delta) {
    if (!_enabled || _viewport.isEmpty) return;
    final before = cursor.value;
    cursor.value = _clamp(before + delta);
    final moved = cursor.value - before;
    _pointer(
      EngineInputEventType.pointerMove,
      _buttons.values.firstOrNull ?? 0,
      delta: moved,
    );
  }

  void setKeys(Object owner, Set<int> keys) {
    if (!_enabled) return;
    final before = _heldKeys;
    if (keys.isEmpty) {
      _keys.remove(owner);
    } else {
      _keys[owner] = Set.of(keys);
    }
    final after = _heldKeys;
    for (final key in before.difference(after)) {
      _key(EngineInputEventType.keyUp, key);
    }
    for (final key in after.difference(before)) {
      _key(EngineInputEventType.keyDown, key);
    }
  }

  void pressMouse(Object owner, int button) {
    if (!_enabled || _buttons.containsKey(owner)) return;
    final alreadyHeld = _buttons.containsValue(button);
    _buttons[owner] = button;
    if (!alreadyHeld) _pointer(EngineInputEventType.pointerDown, button);
  }

  void release(Object owner) {
    final before = _heldKeys;
    _keys.remove(owner);
    for (final key in before.difference(_heldKeys)) {
      _key(EngineInputEventType.keyUp, key);
    }
    final button = _buttons.remove(owner);
    if (button != null && !_buttons.containsValue(button)) {
      _pointer(EngineInputEventType.pointerUp, button);
    }
  }

  Future<void> releaseAll() {
    final keys = _heldKeys;
    final buttons = _buttons.values.toSet();
    _keys.clear();
    _buttons.clear();
    for (final key in keys) {
      _key(EngineInputEventType.keyUp, key);
    }
    for (final button in buttons) {
      _pointer(EngineInputEventType.pointerUp, button);
    }
    return _pending;
  }

  void _key(int type, int key) => _enqueue(
    EngineInputEventData(
      type: type,
      timestampMicros: _clock.elapsedMicroseconds,
      keyCode: key,
      modifiers: _modifiers,
    ),
  );

  void _pointer(int type, int button, {Offset delta = Offset.zero}) => _enqueue(
    EngineInputEventData(
      type: type,
      timestampMicros: _clock.elapsedMicroseconds,
      x: cursor.value.dx,
      y: cursor.value.dy,
      deltaX: delta.dx,
      deltaY: delta.dy,
      pointerId: -1,
      button: button,
      modifiers: _modifiers,
    ),
  );

  void _enqueue(EngineInputEventData event) {
    _pending = _pending.then((_) => send(event)).catchError((Object error) {
      onError(error);
    });
  }

  void dispose() {
    _enabled = false;
    unawaited(releaseAll());
    cursor.dispose();
  }
}

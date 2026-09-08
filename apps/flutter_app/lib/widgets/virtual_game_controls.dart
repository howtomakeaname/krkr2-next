import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../engine/virtual_input_controller.dart';
import '../l10n/app_localizations.dart';
import '../ui/ui.dart';

/// Touch controls sit above the engine surface. Empty areas remain available
/// for direct input; each control consumes its own pointers without forwarding
/// their screen positions as game clicks.
class VirtualGameControls extends StatefulWidget {
  const VirtualGameControls({
    super.key,
    required this.controller,
    required this.enabled,
  });

  final VirtualInputController controller;
  final bool enabled;

  @override
  State<VirtualGameControls> createState() => _VirtualGameControlsState();
}

class _VirtualGameControlsState extends State<VirtualGameControls>
    with WidgetsBindingObserver {
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.controller.setEnabled(widget.enabled));
  }

  @override
  void didUpdateWidget(VirtualGameControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(widget.controller.setEnabled(widget.enabled && _foreground));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    unawaited(widget.controller.setEnabled(widget.enabled && _foreground));
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.controller.setEnabled(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = widget.enabled && _foreground;
    final input = widget.controller;
    Widget keyButton(
      int code,
      String text,
      String label, {
      double width = 48,
    }) => _HoldControl(
      key: ValueKey('virtual-key-$code'),
      input: input,
      enabled: enabled,
      label: label,
      width: width,
      onDown: (owner) => input.setKeys(owner, {code}),
      child: Text(
        text,
        style: context.uiType.caption.copyWith(
          color: context.uiColors.textOnBrand,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    // A game can switch from black to white independently of the app theme.
    // Keep media controls readable over either, using the existing glass material.
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        extensions: [
          ...theme.extensions.values.where((value) => value is! UiGlassTheme),
          UiGlassTheme.dark.copyWith(
            clearFill: context.uiColors.overlay.withValues(alpha: 0.6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          input.setViewport(constraints.biggest);
          return IgnorePointer(
            ignoring: !enabled,
            child: AnimatedOpacity(
              opacity: enabled ? 1 : 0.25,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(painter: _CursorPainter(input)),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: SafeArea(
                      minimum: EdgeInsets.all(
                        constraints.maxWidth < 360 ? 8 : 16,
                      ),
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                keyButton(
                                  GameVirtualKey.control,
                                  'Ctrl',
                                  l10n.virtualSkip,
                                ),
                                const SizedBox(height: 12),
                                _DirectionPad(input: input, enabled: enabled),
                              ],
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: SizedBox(
                              width: 160,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      keyButton(
                                        GameVirtualKey.escape,
                                        'Esc',
                                        l10n.virtualBack,
                                      ),
                                      keyButton(
                                        GameVirtualKey.space,
                                        'Space',
                                        l10n.virtualAdvance,
                                      ),
                                      keyButton(
                                        GameVirtualKey.enter,
                                        'Enter',
                                        l10n.virtualConfirm,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _Touchpad(input: input, enabled: enabled),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      for (final button in [0, 1])
                                        _HoldControl(
                                          key: ValueKey(
                                            'virtual-mouse-$button',
                                          ),
                                          input: input,
                                          enabled: enabled,
                                          label: button == 0
                                              ? l10n.virtualMouseLeft
                                              : l10n.virtualMouseRight,
                                          width: 76,
                                          onDown: (owner) =>
                                              input.pressMouse(owner, button),
                                          child: Text(
                                            button == 0
                                                ? l10n.virtualMouseLeft
                                                : l10n.virtualMouseRight,
                                            style: context.uiType.caption
                                                .copyWith(
                                                  color: context
                                                      .uiColors
                                                      .textOnBrand,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DirectionPad extends StatelessWidget {
  const _DirectionPad({required this.input, required this.enabled});
  final VirtualInputController input;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: 144,
      height: 144,
      child: Stack(
        children: [
          for (final (key, icon, label, offset) in [
            (
              GameVirtualKey.up,
              LucideIcons.chevronUp,
              l10n.virtualUp,
              const Offset(48, 0),
            ),
            (
              GameVirtualKey.left,
              LucideIcons.chevronLeft,
              l10n.virtualLeft,
              const Offset(0, 48),
            ),
            (
              GameVirtualKey.right,
              LucideIcons.chevronRight,
              l10n.virtualRight,
              const Offset(96, 48),
            ),
            (
              GameVirtualKey.down,
              LucideIcons.chevronDown,
              l10n.virtualDown,
              const Offset(48, 96),
            ),
          ])
            Positioned(
              left: offset.dx,
              top: offset.dy,
              child: _HoldControl(
                key: ValueKey('virtual-key-$key'),
                input: input,
                enabled: enabled,
                label: label,
                onDown: (owner) => input.setKeys(owner, {key}),
                child: Icon(
                  icon,
                  size: 22,
                  color: context.uiColors.textOnBrand,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HoldControl extends StatefulWidget {
  const _HoldControl({
    super.key,
    required this.input,
    required this.enabled,
    required this.label,
    required this.onDown,
    required this.child,
    this.width = 48,
  });
  final VirtualInputController input;
  final bool enabled;
  final String label;
  final ValueChanged<Object> onDown;
  final Widget child;
  final double width;

  @override
  State<_HoldControl> createState() => _HoldControlState();
}

class _HoldControlState extends State<_HoldControl> {
  final Set<int> _pointers = {};
  Object owner(int pointer) => (this, pointer);

  void _release(int pointer) {
    widget.input.release(owner(pointer));
    if (mounted) setState(() => _pointers.remove(pointer));
  }

  @override
  void didUpdateWidget(_HoldControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      for (final pointer in _pointers) {
        widget.input.release(owner(pointer));
      }
      _pointers.clear();
    }
  }

  @override
  void dispose() {
    for (final pointer in _pointers) {
      widget.input.release(owner(pointer));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.label,
    enabled: widget.enabled,
    onTap: widget.enabled
        ? () {
            final token = Object();
            widget.onDown(token);
            widget.input.release(token);
          }
        : null,
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (!widget.enabled || !widget.input.enabled) return;
        setState(() => _pointers.add(event.pointer));
        widget.onDown(owner(event.pointer));
      },
      onPointerUp: (event) => _release(event.pointer),
      onPointerCancel: (event) => _release(event.pointer),
      child: RepaintBoundary(
        child: UiGlassSurface(
          variant: UiGlassVariant.clear,
          enableBlur: false,
          borderRadius: BorderRadius.circular(18),
          interaction: _pointers.isEmpty ? 0 : 1,
          tint: _pointers.isEmpty ? null : context.uiColors.brand,
          child: SizedBox(
            width: widget.width,
            height: 48,
            child: Center(child: ExcludeSemantics(child: widget.child)),
          ),
        ),
      ),
    ),
  );
}

class _Touchpad extends StatefulWidget {
  const _Touchpad({required this.input, required this.enabled});
  final VirtualInputController input;
  final bool enabled;
  @override
  State<_Touchpad> createState() => _TouchpadState();
}

class _TouchpadState extends State<_Touchpad> {
  int? _pointer;
  Offset? _start;
  Duration? _startTime;
  bool _moved = false;

  @override
  void didUpdateWidget(_Touchpad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _pointer = null;
  }

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context)!.virtualTouchpad;
    return Semantics(
      label: label,
      child: Listener(
        key: const ValueKey('virtual-touchpad'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (!widget.enabled || !widget.input.enabled || _pointer != null) {
            return;
          }
          setState(() {
            _pointer = event.pointer;
          });
          _start = event.localPosition;
          _startTime = event.timeStamp;
          _moved = false;
        },
        onPointerMove: (event) {
          if (event.pointer != _pointer) return;
          if ((event.localPosition - _start!).distance > 4) _moved = true;
          if (_moved) widget.input.moveCursor(event.delta * 2.5);
        },
        onPointerUp: (event) {
          if (event.pointer != _pointer) return;
          if (!_moved &&
              event.timeStamp - _startTime! <
                  const Duration(milliseconds: 300)) {
            final owner = Object();
            widget.input.pressMouse(owner, 0);
            widget.input.release(owner);
          }
          setState(() {
            _pointer = null;
          });
        },
        onPointerCancel: (event) {
          if (event.pointer == _pointer) {
            setState(() {
              _pointer = null;
            });
          }
        },
        child: RepaintBoundary(
          child: UiGlassSurface(
            enableBlur: false,
            variant: UiGlassVariant.clear,
            borderRadius: BorderRadius.circular(22),
            interaction: _pointer == null ? 0 : 0.5,
            child: SizedBox(
              height: 96,
              width: 160,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.mousePointer2,
                    color: context.uiColors.textOnBrand,
                    size: 22,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: context.uiType.caption.copyWith(
                      color: context.uiColors.textOnBrand.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CursorPainter extends CustomPainter {
  _CursorPainter(this.input) : super(repaint: input.cursor);
  final VirtualInputController input;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(input.cursor.value.dx, input.cursor.value.dy);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, 23)
      ..lineTo(6, 17)
      ..lineTo(11, 27)
      ..lineTo(15, 25)
      ..lineTo(10, 15)
      ..lineTo(19, 15)
      ..close();
    canvas.drawShadow(path, Colors.black, 3, true);
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xff1c1c1e)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CursorPainter oldDelegate) => oldDelegate.input != input;
}

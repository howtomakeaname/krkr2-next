import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/ui_colors.dart';
import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
import 'ui_glass.dart';
import 'ui_icon.dart';

/// Toast 类型。
enum UiToastType { info, success, warning, error }

/// 轻量、短暂的 Toast 提示，非阻塞式。
///
/// 使用 [UiToast.show] 入队展示；如短时间内多次触发会自动合并替换。
class UiToast {
  UiToast._();

  static OverlayEntry? _current;

  static void show(
    BuildContext context, {
    required String message,
    UiToastType type = UiToastType.info,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    _current?.remove();
    _current = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ToastView(
        message: message,
        type: type,
        duration: duration,
        onHide: () {
          if (!identical(_current, entry)) return;
          entry.remove();
          _current = null;
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.message,
    required this.type,
    required this.duration,
    required this.onHide,
  });

  final String message;
  final UiToastType type;
  final Duration duration;
  final VoidCallback onHide;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: UiDuration.base,
    reverseDuration: UiDuration.fast,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: UiCurves.iosSmooth,
    reverseCurve: UiCurves.iosSmooth,
  );
  late final Animation<double> _motion = CurvedAnimation(
    parent: _controller,
    curve: UiCurves.iosSpringOut,
    reverseCurve: UiCurves.iosSmooth,
  );
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: const Offset(0, 0.18),
    end: Offset.zero,
  ).animate(_motion);
  late final Animation<double> _scale = Tween<double>(
    begin: 0.92,
    end: 1,
  ).animate(_motion);
  Timer? _hideTimer;
  bool _dismissing = false;
  bool _reduceMotion = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
    if (_reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
    _hideTimer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted || _dismissing) return;
    _dismissing = true;
    if (!_reduceMotion) await _controller.reverse();
    if (mounted) widget.onHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  (IconData, Color) _decor(UiColors colors) {
    switch (widget.type) {
      case UiToastType.success:
        return (UiIcons.success, colors.success);
      case UiToastType.warning:
        return (UiIcons.warning, colors.warning);
      case UiToastType.error:
        return (UiIcons.error, colors.danger);
      case UiToastType.info:
        return (UiIcons.info, colors.brand);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final (icon, tint) = _decor(colors);

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 76),
          child: FadeTransition(
            opacity: _opacity,
            child: SlideTransition(
              position: _offset,
              child: ScaleTransition(
                scale: _scale,
                alignment: Alignment.bottomCenter,
                child: Material(
                  color: Colors.transparent,
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    label: widget.message,
                    child: GestureDetector(
                      onTap: _dismiss,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: 48,
                          maxWidth: 360,
                        ),
                        child: UiGlassSurface(
                          key: const ValueKey<String>('ui-toast-surface'),
                          variant: UiGlassVariant.regular,
                          borderRadius: UiRadius.brXl,
                          tint: widget.type == UiToastType.info ? null : tint,
                          blurScale: 0.72,
                          materialStrength: 0.96,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 18, color: tint),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  widget.message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: typography.callout.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

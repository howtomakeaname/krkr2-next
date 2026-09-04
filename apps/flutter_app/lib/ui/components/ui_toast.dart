import 'package:flutter/material.dart';

import '../theme/ui_colors.dart';
import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
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

    final entry = OverlayEntry(
      builder: (ctx) => _ToastView(
        message: message,
        type: type,
        duration: duration,
        onHide: () {
          _current?.remove();
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
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: UiCurves.standard,
  );
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: const Offset(0, 0.25),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: UiCurves.emphasized));

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future.delayed(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onHide();
  }

  @override
  void dispose() {
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
          padding: const EdgeInsets.only(bottom: 64),
          child: FadeTransition(
            opacity: _opacity,
            child: SlideTransition(
              position: _offset,
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: UiSpacing.lg,
                      vertical: UiSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: UiRadius.brLg,
                      boxShadow: [
                        BoxShadow(
                          color: colors.overlay.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 20, color: tint),
                        const SizedBox(width: UiSpacing.sm),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: typography.callout.copyWith(
                              color: colors.textPrimary,
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
    );
  }
}

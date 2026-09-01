import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// iOS18 风格 Tooltip：深色圆角 + 白字 + 柔和阴影。
///
/// 触发方式：长按/悬浮。底层基于 Flutter 内建 [Tooltip]，仅覆盖样式。
class UiTooltip extends StatelessWidget {
  const UiTooltip({
    super.key,
    required this.message,
    required this.child,
    this.verticalOffset = 12,
    this.preferBelow = false,
    this.waitDuration = const Duration(milliseconds: 450),
  });

  final String message;
  final Widget child;
  final double verticalOffset;
  final bool preferBelow;
  final Duration waitDuration;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;

    return Tooltip(
      message: message,
      verticalOffset: verticalOffset,
      preferBelow: preferBelow,
      waitDuration: waitDuration,
      padding: const EdgeInsets.symmetric(
          horizontal: UiSpacing.md, vertical: UiSpacing.sm),
      decoration: BoxDecoration(
        color: colors.textPrimary.withValues(alpha: 0.92),
        borderRadius: UiRadius.brSm,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      textStyle: typography.footnote.copyWith(color: colors.background),
      child: child,
    );
  }
}

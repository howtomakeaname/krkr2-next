import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// iOS 角标（通知小红点）组件。
///
/// - [count] > 0：显示数字；超过 [maxCount] 显示 `99+`；
/// - [count] == 0 且 [dot] = true：显示小红点；
/// - [child] 不为 null 时会叠加到右上角。
class UiBadge extends StatelessWidget {
  const UiBadge({
    super.key,
    this.child,
    this.count,
    this.dot = false,
    this.maxCount = 99,
    this.color,
    this.textColor,
    this.offset = const Offset(2, -2),
  });

  final Widget? child;
  final int? count;
  final bool dot;
  final int maxCount;
  final Color? color;
  final Color? textColor;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final show = dot || (count != null && count! > 0);
    if (!show) {
      return child ?? const SizedBox.shrink();
    }

    final bg = color ?? colors.danger;
    final fg = textColor ?? colors.textOnBrand;

    final badge = dot || count == null
        ? Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: colors.background, width: 1.4),
            ),
          )
        : Container(
            constraints: const BoxConstraints(
              minWidth: 18,
              minHeight: 18,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: UiRadius.brPill,
              border: child != null
                  ? Border.all(color: colors.background, width: 1.4)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              count! > maxCount ? '$maxCount+' : '$count',
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          );

    if (child == null) return badge;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child!,
        Positioned(
          right: offset.dx,
          top: offset.dy,
          child: badge,
        ),
      ],
    );
  }
}

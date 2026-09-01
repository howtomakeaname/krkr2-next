import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// 基础卡片容器。iOS18 风格：圆角 18、柔和阴影、浅色边界描边。
///
/// 通过 [padding]、[borderRadius] 可以覆写默认样式，常用于组合其他组件。
class UiCard extends StatelessWidget {
  const UiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(UiSpacing.lg),
    this.borderRadius = UiRadius.brLg,
    this.color,
    this.clip = Clip.antiAlias,
    this.elevation = 0,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? color;
  final Clip clip;
  final double elevation;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    return Container(
      clipBehavior: clip,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: borderRadius,
        border: border,
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06 * elevation),
                  blurRadius: 16 * elevation,
                  offset: Offset(0, 6 * elevation),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

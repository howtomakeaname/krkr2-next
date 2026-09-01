import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// 线性进度条。
///
/// - [value] 为 null 时为不确定进度（与 [LinearProgressIndicator] 默认动画一致）；
/// - 有值时为确定进度（0..1）。
class UiProgress extends StatelessWidget {
  const UiProgress({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.height = 6,
  });

  final double? value;
  final Color? color;
  final Color? backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    return ClipRRect(
      borderRadius: UiRadius.brPill,
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: value,
          minHeight: height,
          backgroundColor: backgroundColor ?? colors.separator,
          valueColor: AlwaysStoppedAnimation<Color>(color ?? colors.brand),
        ),
      ),
    );
  }
}

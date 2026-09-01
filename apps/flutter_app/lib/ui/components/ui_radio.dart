import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// iOS 风格单选按钮。
///
/// - 选中态：实心圆点 + 品牌色圆环；
/// - 未选中：浅灰圆环；
/// - 支持 [label] 与点击态动画。
class UiRadio<T> extends StatelessWidget {
  const UiRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.label,
    this.enabled = true,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;
  final String? label;
  final bool enabled;

  bool get _selected => value == groupValue;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;

    final dot = AnimatedContainer(
      duration: UiDuration.fast,
      curve: UiCurves.standard,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: _selected ? colors.brand : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: _selected ? colors.brand : colors.border,
          width: _selected ? 0 : 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: _selected
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colors.textOnBrand,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );

    final tap = enabled ? () => onChanged?.call(value) : null;

    if (label == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: Opacity(opacity: enabled ? 1 : 0.5, child: dot),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tap,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot,
            const SizedBox(width: UiSpacing.sm),
            Flexible(
              child: Text(label!,
                  style: typography.body.copyWith(color: colors.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
import 'ui_icon.dart';

/// iOS18 风格多选框。
///
/// 选中态为蓝色填充圆角方块 + 白色对钩，未选中为浅色描边。
class UiCheckbox extends StatelessWidget {
  const UiCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.enabled = true,
    this.tristate = false,
  });

  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final String? label;
  final bool enabled;
  final bool tristate;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;

    final box = AnimatedContainer(
      duration: UiDuration.fast,
      curve: UiCurves.standard,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: value == true ? colors.brand : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: value == true ? colors.brand : colors.border,
          width: value == true ? 0 : 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: value == true
          ? UiIcon(UiIcons.check, size: 14, color: colors.textOnBrand)
          : value == null
              ? Container(
                  width: 10,
                  height: 2,
                  color: colors.textSecondary,
                )
              : null,
    );

    final handler = enabled
        ? () {
            if (tristate) {
              bool? next;
              if (value == false) {
                next = true;
              } else if (value == true) {
                next = null;
              } else {
                next = false;
              }
              onChanged?.call(next);
            } else {
              onChanged?.call(!(value ?? false));
            }
          }
        : null;

    if (label == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: handler,
        child: Opacity(opacity: enabled ? 1 : 0.5, child: box),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: handler,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            box,
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

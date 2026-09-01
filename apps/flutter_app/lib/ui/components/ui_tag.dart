import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// 标签类型，决定默认的配色。
enum UiTagTone { neutral, brand, success, warning, danger }

/// iOS18 风格标签 / Chip。
///
/// 支持：
/// - 语义化色调（[UiTagTone]）；
/// - 前置图标（[icon]）；
/// - 可关闭（[onRemoved]）；
/// - 可点击（[onTap]，作为 filter chip 使用时配合 [selected]）。
class UiTag extends StatelessWidget {
  const UiTag({
    super.key,
    required this.label,
    this.icon,
    this.tone = UiTagTone.neutral,
    this.onTap,
    this.onRemoved,
    this.selected = false,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final UiTagTone tone;
  final VoidCallback? onTap;
  final VoidCallback? onRemoved;
  final bool selected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final palette = _palette(colors);

    final bg = selected ? palette.$1 : palette.$1.withValues(alpha: 0.16);
    final fg = selected ? colors.textOnBrand : palette.$2;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: UiDuration.fast,
        curve: UiCurves.standard,
        padding: EdgeInsets.symmetric(
          horizontal: dense ? UiSpacing.sm : UiSpacing.md,
          vertical: dense ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: UiRadius.brPill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: dense ? 12 : 14, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: typography.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: dense ? 11 : 12,
              ),
            ),
            if (onRemoved != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onRemoved,
                child: Icon(Icons.close, size: dense ? 12 : 14, color: fg),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (Color, Color) _palette(colors) {
    switch (tone) {
      case UiTagTone.brand:
        return (colors.brand, colors.brand);
      case UiTagTone.success:
        return (colors.success, colors.success);
      case UiTagTone.warning:
        return (colors.warning, colors.warning);
      case UiTagTone.danger:
        return (colors.danger, colors.danger);
      case UiTagTone.neutral:
        return (colors.textSecondary, colors.textSecondary);
    }
  }
}

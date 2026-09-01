import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
import 'ui_icon.dart';

/// 信息条语义（决定底色与图标颜色）。
enum UiBannerTone { info, success, warning, danger }

/// 信息条：常驻于页面顶部或区块顶部的非阻塞提示。
///
/// 与 [UiSnackbar] 的差异：Banner 通常是"常驻"的（例如"您处于只读模式"
/// 提示），而 Snackbar 是"短暂出现后消失"的。
class UiBanner extends StatelessWidget {
  const UiBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = UiBannerTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.onClose,
    this.filled = false,
  });

  final String message;
  final String? title;
  final UiBannerTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 关闭回调。不为 null 时显示关闭按钮。
  final VoidCallback? onClose;

  /// 实心样式：更抢眼，用于重要提示；默认 false 为弱化背景。
  final bool filled;

  (Color, Color, IconData) _palette(colors) {
    switch (tone) {
      case UiBannerTone.info:
        return (colors.brand, colors.brand, UiIcons.info);
      case UiBannerTone.success:
        return (colors.success, colors.success, UiIcons.success);
      case UiBannerTone.warning:
        return (colors.warning, colors.warning, UiIcons.warning);
      case UiBannerTone.danger:
        return (colors.danger, colors.danger, UiIcons.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final (accent, fgDefault, defaultIcon) = _palette(colors);

    final bg = filled ? accent : accent.withValues(alpha: 0.12);
    final fg = filled ? colors.textOnBrand : fgDefault;
    final titleColor = filled ? colors.textOnBrand : colors.textPrimary;
    final msgColor = filled
        ? colors.textOnBrand.withValues(alpha: 0.85)
        : colors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(UiSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: UiRadius.brMd,
        border: filled ? null : Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, size: 20, color: fg),
          const SizedBox(width: UiSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(title!,
                        style: typography.headline
                            .copyWith(color: titleColor, fontSize: 15)),
                  ),
                Text(message,
                    style: typography.subheadline.copyWith(color: msgColor)),
                if (actionLabel != null && onAction != null)
                  Padding(
                    padding: const EdgeInsets.only(top: UiSpacing.sm),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onAction,
                      child: Text(
                        actionLabel!,
                        style: typography.callout.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: UiSpacing.xs),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(UiIcons.close,
                    size: 16,
                    color: filled ? colors.textOnBrand : colors.textTertiary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

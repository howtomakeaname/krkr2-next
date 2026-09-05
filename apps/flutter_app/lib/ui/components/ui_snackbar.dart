import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
import 'ui_button.dart';
import 'ui_glass.dart';
import 'ui_icon.dart';

/// SnackBar 类型。
enum UiSnackbarType { info, success, warning, error }

/// iOS18 风格 Snackbar：支持图标、文案以及可选的操作按钮。
///
/// 通过 [UiSnackbar.show] 使用：
/// ```dart
/// UiSnackbar.show(context, message: '已保存', type: UiSnackbarType.success);
/// ```
class UiSnackbar {
  UiSnackbar._();

  static void show(
    BuildContext context, {
    required String message,
    UiSnackbarType type = UiSnackbarType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final colors = context.uiColors;
    final typography = context.uiType;

    final (icon, tint) = _decor(type, colors);

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.all(UiSpacing.lg),
        padding: EdgeInsets.zero,
        content: UiGlassSurface(
          variant: UiGlassVariant.regular,
          borderRadius: UiRadius.brLg,
          enableBlur: true,
          padding: const EdgeInsets.fromLTRB(
            UiSpacing.lg,
            UiSpacing.sm,
            UiSpacing.sm,
            UiSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, color: tint, size: 20),
              const SizedBox(width: UiSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: typography.callout.copyWith(color: colors.textPrimary),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (actionLabel != null) ...[
                const SizedBox(width: UiSpacing.xs),
                UiButton(
                  label: actionLabel,
                  size: UiButtonSize.small,
                  variant: UiButtonVariant.ghost,
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    onAction?.call();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static (IconData, Color) _decor(UiSnackbarType type, colors) {
    switch (type) {
      case UiSnackbarType.success:
        return (UiIcons.success, colors.success);
      case UiSnackbarType.warning:
        return (UiIcons.warning, colors.warning);
      case UiSnackbarType.error:
        return (UiIcons.error, colors.danger);
      case UiSnackbarType.info:
        return (UiIcons.info, colors.brand);
    }
  }
}

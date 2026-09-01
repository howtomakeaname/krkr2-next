import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
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
        backgroundColor: colors.surfaceElevated,
        elevation: 0,
        margin: const EdgeInsets.all(UiSpacing.lg),
        padding: const EdgeInsets.symmetric(
            horizontal: UiSpacing.lg, vertical: UiSpacing.md),
        shape: const RoundedRectangleBorder(borderRadius: UiRadius.brLg),
        content: Row(
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
          ],
        ),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: colors.brand,
                onPressed: onAction ?? () {},
              )
            : null,
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

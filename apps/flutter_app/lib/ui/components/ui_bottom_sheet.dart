import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
import 'ui_button.dart';
import 'ui_icon.dart';

/// iOS18 风格底部抽屉。
///
/// 特性：
/// - 顶部带抓手指示条，支持下拉关闭；
/// - 自动根据屏幕宽度约束最大宽度（平板友好）；
/// - 可选 [title]；
/// - 内容默认可滚动。
class UiBottomSheet {
  UiBottomSheet._();

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool showHandle = true,
    bool showCloseButton = false,
    bool isScrollControlled = true,
    bool barrierDismissible = true,
    double? maxWidth,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: barrierDismissible,
      backgroundColor: Colors.transparent,
      barrierColor: context.uiColors.overlay,
      useSafeArea: true,
      constraints: BoxConstraints(maxWidth: maxWidth ?? 560),
      builder: (ctx) => _SheetView(
        title: title,
        showHandle: showHandle,
        showCloseButton: showCloseButton,
        child: child,
      ),
    );
  }
}

class _SheetView extends StatelessWidget {
  const _SheetView({
    this.title,
    required this.child,
    required this.showHandle,
    required this.showCloseButton,
  });

  final String? title;
  final Widget child;
  final bool showHandle;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: UiRadius.xxl),
          boxShadow: [
            BoxShadow(
              color: colors.overlay.withValues(alpha: 0.16),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHandle)
              Padding(
                padding: const EdgeInsets.only(top: UiSpacing.sm),
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.separator,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            if (title != null || showCloseButton)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  UiSpacing.xl,
                  UiSpacing.md,
                  UiSpacing.sm,
                  UiSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title ?? '',
                        style: typography.title3.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (showCloseButton)
                      UiButton.icon(
                        icon: UiIcons.close,
                        variant: UiButtonVariant.ghost,
                        size: UiButtonSize.small,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                  ],
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  UiSpacing.xl,
                  UiSpacing.sm,
                  UiSpacing.xl,
                  UiSpacing.xl,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

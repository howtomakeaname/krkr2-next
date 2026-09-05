import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_springs.dart';
import '../theme/ui_theme.dart';
import 'ui_glass.dart';
import 'ui_icon.dart';

/// iOS18 风格中央模态框。
///
/// 与 [UiDialog] 不同，[UiModal] 承载更丰富的自由内容（表单、长列表等），
/// 宽屏上会自动居中并限制最大宽度 [maxWidth]，长内容自动滚动。
class UiModal {
  UiModal._();

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    double maxWidth = 520,
    double? maxHeight,
    bool barrierDismissible = true,
    bool showCloseButton = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'UiModal',
      barrierColor: context.uiColors.overlay,
      transitionDuration: UiSprings.materializeDuration,
      pageBuilder: (ctx, a, b) => _ModalView(
        title: title,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        showCloseButton: showCloseButton,
        child: child,
      ),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: UiSprings.materializeCurve,
          reverseCurve: UiSprings.dismissCurve,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

class _ModalView extends StatelessWidget {
  const _ModalView({
    this.title,
    required this.child,
    required this.maxWidth,
    this.maxHeight,
    required this.showCloseButton,
  });

  final String? title;
  final Widget child;
  final double maxWidth;
  final double? maxHeight;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final size = MediaQuery.sizeOf(context);
    final targetHeight = maxHeight ?? size.height * 0.78;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(UiSpacing.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: targetHeight,
          ),
          child: Material(
            color: Colors.transparent,
            child: UiGlassSurface(
              variant: UiGlassVariant.regular,
              borderRadius: UiRadius.brXl,
              enableBlur: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null || showCloseButton)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        UiSpacing.xl,
                        UiSpacing.lg,
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
                            UiGlassIconButton(
                              icon: UiIcons.close,
                              semanticLabel: 'Close',
                              size: 36,
                              iconSize: 18,
                              contained: false,
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                        ],
                      ),
                    ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        UiSpacing.xl,
                        0,
                        UiSpacing.xl,
                        UiSpacing.xl,
                      ),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

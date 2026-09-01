import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
import 'ui_button.dart';
import 'ui_icon.dart';

/// 空态占位组件。
///
/// 通常用在列表为空、搜索无结果、网络异常等场景。
class UiEmpty extends StatelessWidget {
  const UiEmpty({
    super.key,
    this.title = '暂无内容',
    this.description,
    this.icon = UiIcons.folder,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(UiSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.groupedBackground,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 32, color: colors.textTertiary),
            ),
            const SizedBox(height: UiSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: typography.headline
                  .copyWith(color: colors.textPrimary),
            ),
            if (description != null) ...[
              const SizedBox(height: UiSpacing.xs),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: typography.subheadline
                    .copyWith(color: colors.textSecondary),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: UiSpacing.lg),
              UiButton(
                label: actionLabel!,
                variant: UiButtonVariant.secondary,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

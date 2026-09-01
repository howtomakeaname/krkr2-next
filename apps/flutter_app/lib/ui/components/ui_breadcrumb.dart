import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

class UiBreadcrumbItem {
  const UiBreadcrumbItem({required this.label, this.icon, this.onTap});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
}

/// 面包屑导航。
///
/// - 水平滚动，避免窄屏下溢出；
/// - 最后一项高亮为 textPrimary 且不可点击；
/// - 支持自定义分隔符（默认 `›`）。
class UiBreadcrumb extends StatelessWidget {
  const UiBreadcrumb({
    super.key,
    required this.items,
    this.separator = '›',
    this.maxLines = 1,
  }) : assert(items.length > 0);

  final List<UiBreadcrumbItem> items;
  final String separator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;

    final widgets = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      final isLast = i == items.length - 1;
      final item = items[i];
      widgets.add(_Crumb(
        label: item.label,
        icon: item.icon,
        isLast: isLast,
        onTap: isLast ? null : item.onTap,
      ));
      if (!isLast) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: UiSpacing.xs),
          child: Text(
            separator,
            style: typography.subheadline
                .copyWith(color: colors.textTertiary, fontWeight: FontWeight.w500),
          ),
        ));
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: widgets,
      ),
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({
    required this.label,
    required this.icon,
    required this.isLast,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final style = typography.subheadline.copyWith(
      color: isLast
          ? colors.textPrimary
          : (onTap != null ? colors.brand : colors.textSecondary),
      fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: style.color),
          const SizedBox(width: 4),
        ],
        Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: content,
        ),
      ),
    );
  }
}

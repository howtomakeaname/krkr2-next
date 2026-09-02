import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// iOS 分组列表章节容器。自动在卡片内添加分隔线、并在卡片外
/// 显示 [header] / [footer] 说明文本。
class UiListSection extends StatelessWidget {
  const UiListSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.padding = const EdgeInsets.symmetric(horizontal: UiSpacing.lg),
    this.showDividers = true,
    this.insetDividers = true,
  });

  final List<Widget> children;
  final String? header;
  final String? footer;
  final EdgeInsetsGeometry padding;
  final bool showDividers;

  /// 分割线是否缩进（避开 leading icon）。
  final bool insetDividers;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (showDividers && i != children.length - 1) {
        rows.add(Divider(
          height: 0.6,
          thickness: 0.6,
          color: colors.separator,
          indent: insetDividers ? UiSpacing.lg : 0,
          endIndent: 0,
        ));
      }
    }

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  UiSpacing.xs, UiSpacing.lg, UiSpacing.xs, UiSpacing.sm),
              child: Text(
                header!.toUpperCase(),
                style: typography.caption.copyWith(
                  color: colors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          Material(
            color: colors.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: UiRadius.brLg,
              side: BorderSide(color: colors.border, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: rows,
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  UiSpacing.xs, UiSpacing.sm, UiSpacing.xs, UiSpacing.lg),
              child: Text(
                footer!,
                style: typography.caption.copyWith(color: colors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

enum UiTimelineTone { neutral, brand, success, warning, danger }

class UiTimelineItem {
  const UiTimelineItem({
    required this.title,
    this.subtitle,
    this.timestamp,
    this.icon,
    this.tone = UiTimelineTone.neutral,
    this.trailing,
    this.highlight = false,
  });

  final String title;
  final String? subtitle;
  final String? timestamp;
  final IconData? icon;
  final UiTimelineTone tone;
  final Widget? trailing;

  /// 高亮节点（通常用于 "当前" 步骤），节点外会有一圈光晕。
  final bool highlight;
}

/// 竖向时间轴。
///
/// 典型使用场景：订单物流、审批流水、活动日志。每个节点：
/// - 左列固定 32px 宽度放置圆点 + 连接线；
/// - 右列放置标题 / 副标题 / 时间戳 / trailing；
/// - 首尾节点会自动隐藏顶/底连接线。
class UiTimeline extends StatelessWidget {
  const UiTimeline({
    super.key,
    required this.items,
    this.dense = false,
  });

  final List<UiTimelineItem> items;

  /// 紧凑模式减小行间距。
  final bool dense;

  Color _toneColor(UiTimelineTone tone, BuildContext context) {
    final c = context.uiColors;
    switch (tone) {
      case UiTimelineTone.neutral:
        return c.textSecondary;
      case UiTimelineTone.brand:
        return c.brand;
      case UiTimelineTone.success:
        return c.success;
      case UiTimelineTone.warning:
        return c.warning;
      case UiTimelineTone.danger:
        return c.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final gap = dense ? UiSpacing.sm : UiSpacing.lg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < items.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      // 顶部连接线
                      SizedBox(
                        width: 2,
                        height: 6,
                        child: ColoredBox(
                          color: i == 0 ? Colors.transparent : colors.border,
                        ),
                      ),
                      _Dot(
                        color: _toneColor(items[i].tone, context),
                        icon: items[i].icon,
                        highlight: items[i].highlight,
                      ),
                      // 底部连接线
                      if (i != items.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: colors.border,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: UiSpacing.md),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i == items.length - 1 ? 0 : gap,
                      top: 4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                items[i].title,
                                style: typography.headline.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              if (items[i].subtitle != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    items[i].subtitle!,
                                    style: typography.subheadline.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                              if (items[i].timestamp != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    items[i].timestamp!,
                                    style: typography.caption.copyWith(
                                      color: colors.textTertiary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (items[i].trailing != null) ...[
                          const SizedBox(width: UiSpacing.sm),
                          items[i].trailing!,
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.icon, required this.highlight});
  final Color color;
  final IconData? icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final inner = Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: icon == null ? color : colors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: icon == null ? null : Icon(icon, size: 8, color: color),
    );

    if (!highlight) return Padding(padding: const EdgeInsets.all(2), child: inner);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: inner,
    );
  }
}

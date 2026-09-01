import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
import 'ui_badge.dart';

/// 底部导航栏单个项目。
class UiNavItem {
  const UiNavItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.badgeCount,
    this.badgeDot = false,
  });

  final IconData icon;
  final String label;
  final IconData? activeIcon;
  final int? badgeCount;
  final bool badgeDot;
}

/// iOS 风格底部 Tab 栏。
///
/// - 图标在上、标签在下；
/// - 选中项文字 + 图标采用品牌色；
/// - 支持 [UiBadge] 叠加显示未读 / 小红点；
/// - 使用 [SafeArea] 底部自动避让小黑条。
class UiNavBar extends StatelessWidget {
  const UiNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    this.backgroundColor,
    this.showLabel = true,
    this.enableHaptic = true,
  }) : assert(items.length >= 2);

  final List<UiNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final Color? backgroundColor;
  final bool showLabel;
  final bool enableHaptic;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final bg = backgroundColor ?? colors.surface;

    return Material(
      color: bg,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(top: BorderSide(color: colors.separator, width: 0.6)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: showLabel ? 58 : 48,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: items[i],
                      selected: i == currentIndex,
                      showLabel: showLabel,
                      onTap: () {
                        if (i == currentIndex) return;
                        if (enableHaptic) HapticFeedback.selectionClick();
                        onChanged(i);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final UiNavItem item;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final active = selected ? colors.brand : colors.textSecondary;

    final icon = Icon(
      selected ? (item.activeIcon ?? item.icon) : item.icon,
      size: 24,
      color: active,
    );

    final badged = (item.badgeDot || (item.badgeCount != null && item.badgeCount! > 0))
        ? UiBadge(
            dot: item.badgeDot,
            count: item.badgeCount,
            offset: const Offset(4, -4),
            child: icon,
          )
        : icon;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: UiSpacing.xs),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            badged,
            if (showLabel) ...[
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: UiDuration.fast,
                style: typography.caption.copyWith(
                  color: active,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

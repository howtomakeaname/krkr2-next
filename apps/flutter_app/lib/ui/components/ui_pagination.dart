import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// 分页器：数字页码 + 上一页 / 下一页。
///
/// - 页码过多时自动折叠为 `1 ... 5 6 [7] 8 9 ... 20` 样式；
/// - [siblingCount] 控制当前页两侧显示几个兄弟页；
/// - [compact] 模式下只显示 "< 7/20 >"，适合移动端窄屏。
class UiPagination extends StatelessWidget {
  const UiPagination({
    super.key,
    required this.current,
    required this.total,
    required this.onChanged,
    this.siblingCount = 1,
    this.compact = false,
  })  : assert(current >= 1 && total >= 1, 'current/total 必须 >= 1');

  final int current;
  final int total;
  final ValueChanged<int> onChanged;
  final int siblingCount;
  final bool compact;

  void _go(int page) {
    if (page == current || page < 1 || page > total) return;
    HapticFeedback.selectionClick();
    onChanged(page);
  }

  List<_PageItem> _buildItems() {
    if (total <= 7 + siblingCount * 2) {
      return [for (int i = 1; i <= total; i++) _PageItem.page(i)];
    }

    final items = <_PageItem>[];
    final start = (current - siblingCount).clamp(2, total - 1);
    final end = (current + siblingCount).clamp(2, total - 1);

    items.add(_PageItem.page(1));
    if (start > 2) items.add(_PageItem.ellipsis());
    for (int i = start; i <= end; i++) {
      items.add(_PageItem.page(i));
    }
    if (end < total - 1) items.add(_PageItem.ellipsis());
    items.add(_PageItem.page(total));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Arrow(
            icon: Icons.chevron_left_rounded,
            enabled: current > 1,
            onTap: () => _go(current - 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: UiSpacing.md),
            child: Text(
              '$current / $total',
              style: typography.subheadline
                  .copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
          _Arrow(
            icon: Icons.chevron_right_rounded,
            enabled: current < total,
            onTap: () => _go(current + 1),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Arrow(
          icon: Icons.chevron_left_rounded,
          enabled: current > 1,
          onTap: () => _go(current - 1),
        ),
        for (final item in _buildItems())
          if (item.isEllipsis)
            const _Ellipsis()
          else
            _PageButton(
              page: item.page!,
              active: item.page == current,
              onTap: () => _go(item.page!),
            ),
        _Arrow(
          icon: Icons.chevron_right_rounded,
          enabled: current < total,
          onTap: () => _go(current + 1),
        ),
      ],
    );
  }
}

class _PageItem {
  _PageItem._(this.page);
  factory _PageItem.page(int page) => _PageItem._(page);
  factory _PageItem.ellipsis() => _PageItem._(null);
  final int? page;
  bool get isEllipsis => page == null;
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.page,
    required this.active,
    required this.onTap,
  });

  final int page;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: UiRadius.brSm,
        child: AnimatedContainer(
          duration: UiDuration.fast,
          curve: UiCurves.standard,
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? colors.brand : colors.surface,
            borderRadius: UiRadius.brSm,
            border: Border.all(
              color: active ? colors.brand : colors.border,
              width: 1,
            ),
          ),
          child: Text(
            '$page',
            style: typography.subheadline.copyWith(
              color: active ? colors.textOnBrand : colors.textPrimary,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: UiRadius.brSm,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: UiRadius.brSm,
            border: Border.all(color: colors.border, width: 1),
          ),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? colors.textPrimary : colors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _Ellipsis extends StatelessWidget {
  const _Ellipsis();

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    return SizedBox(
      width: 24,
      height: 32,
      child: Center(
        child: Text(
          '···',
          style:
              typography.subheadline.copyWith(color: colors.textTertiary),
        ),
      ),
    );
  }
}

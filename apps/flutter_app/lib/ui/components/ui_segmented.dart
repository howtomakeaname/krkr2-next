import 'package:flutter/material.dart';

import '../theme/ui_colors.dart';
import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
import '../theme/ui_typography.dart';

/// iOS 分段控制器选项。
class UiSegmentedItem<T> {
  const UiSegmentedItem({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// iOS18 Segmented Control。
///
/// 与 [UiTabs] 的差异：
/// - Segmented 更强调 "互斥选项"，语义上用于 "视图模式" 或 "筛选条件"，
///   而 Tabs 用于 "页面导航"；
/// - 视觉密度更紧凑；
/// - 值类型是泛型 [T] 而非索引，更贴合业务。
///
/// 底层仍使用 [AnimatedAlign] + [FractionallySizedBox] 做指示器平滑滑动，
/// 保持与 [UiTabs] 一致的性能特征。
class UiSegmented<T> extends StatelessWidget {
  const UiSegmented({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final List<UiSegmentedItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final count = items.length;
    final idx = items.indexWhere((e) => e.value == value);
    final safeIdx = idx < 0 ? 0 : idx;
    final alignX = count <= 1 ? 0.0 : (safeIdx / (count - 1)) * 2 - 1;

    // 组件内部使用 Stack + Positioned.fill + Expanded 实现等宽分段与滑动
    // 指示器，必须在有限宽度约束中使用。外层通常应 `Expanded` / `SizedBox`
    // / `ConstrainedBox(maxWidth: ...)` 提供边界。
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.maxWidth.isFinite,
          'UiSegmented 需要有限的宽度约束，请用 Expanded / SizedBox / '
          'ConstrainedBox 包裹它。',
        );
        return RepaintBoundary(
          child: _buildContent(colors, typography, count, safeIdx, alignX),
        );
      },
    );
  }

  Widget _buildContent(
    UiColors colors,
    UiTypography typography,
    int count,
    int safeIdx,
    double alignX,
  ) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.groupedBackground,
        borderRadius: UiRadius.brMd,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              duration: UiDuration.base,
              curve: UiCurves.emphasized,
              alignment: Alignment(alignX, 0),
              child: FractionallySizedBox(
                widthFactor: 1 / count,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: UiRadius.brSm,
                    boxShadow: [
                      BoxShadow(
                        color: colors.overlay.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < count; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(items[i].value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: UiSpacing.sm,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (items[i].icon != null) ...[
                            Icon(
                              items[i].icon,
                              size: 15,
                              color: i == safeIdx
                                  ? colors.textPrimary
                                  : colors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                          ],
                          AnimatedDefaultTextStyle(
                            duration: UiDuration.fast,
                            style: typography.footnote.copyWith(
                              color: i == safeIdx
                                  ? colors.textPrimary
                                  : colors.textSecondary,
                              fontWeight: i == safeIdx
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                            child: Text(items[i].label),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

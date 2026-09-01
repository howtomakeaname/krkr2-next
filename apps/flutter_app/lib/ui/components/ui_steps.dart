import 'package:flutter/material.dart';

import '../theme/ui_colors.dart';
import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

enum UiStepsDirection { horizontal, vertical }

enum UiStepStatus { wait, process, done, error }

class UiStepItem {
  const UiStepItem({
    required this.title,
    this.description,
    this.icon,
    this.status,
  });

  final String title;
  final String? description;
  final IconData? icon;

  /// 手动覆盖此步骤的状态；不指定则由 [UiSteps.currentIndex] 推导。
  final UiStepStatus? status;
}

/// 步骤指示器 / Stepper。
///
/// - 默认横向排列（适合订单进度、多步表单顶部）；
/// - [UiStepsDirection.vertical] 为竖排（适合物流时间轴等场景）；
/// - 节点圆形 + 连接线，节点状态由 [currentIndex] 自动推导；
/// - 可通过 [UiStepItem.status] 单独设置某一步的状态（如 [UiStepStatus.error]）。
class UiSteps extends StatelessWidget {
  const UiSteps({
    super.key,
    required this.steps,
    required this.currentIndex,
    this.direction = UiStepsDirection.horizontal,
    this.compact = false,
    this.onStepTapped,
  });

  final List<UiStepItem> steps;
  final int currentIndex;
  final UiStepsDirection direction;

  /// 紧凑模式下横向排列只显示节点与连接线，不显示文字。
  final bool compact;

  final ValueChanged<int>? onStepTapped;

  UiStepStatus _resolveStatus(int i) {
    final override = steps[i].status;
    if (override != null) return override;
    if (i < currentIndex) return UiStepStatus.done;
    if (i == currentIndex) return UiStepStatus.process;
    return UiStepStatus.wait;
  }

  @override
  Widget build(BuildContext context) {
    if (direction == UiStepsDirection.vertical) {
      return _buildVertical(context);
    }
    return _buildHorizontal(context);
  }

  Widget _buildHorizontal(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    // 左侧连接线
                    Expanded(
                      child: i == 0
                          ? const SizedBox.shrink()
                          : _Connector(
                              active: _resolveStatus(i) != UiStepStatus.wait,
                              colors: colors,
                            ),
                    ),
                    GestureDetector(
                      onTap: onStepTapped == null ? null : () => onStepTapped!(i),
                      child: _Node(
                        index: i,
                        status: _resolveStatus(i),
                        icon: steps[i].icon,
                      ),
                    ),
                    Expanded(
                      child: i == steps.length - 1
                          ? const SizedBox.shrink()
                          : _Connector(
                              active: _resolveStatus(i + 1) != UiStepStatus.wait,
                              colors: colors,
                            ),
                    ),
                  ],
                ),
                if (!compact) ...[
                  const SizedBox(height: UiSpacing.sm),
                  Text(
                    steps[i].title,
                    style: typography.subheadline.copyWith(
                      color: _resolveStatus(i) == UiStepStatus.wait
                          ? colors.textTertiary
                          : colors.textPrimary,
                      fontWeight: _resolveStatus(i) == UiStepStatus.process
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (steps[i].description != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        steps[i].description!,
                        style: typography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVertical(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    _Node(
                      index: i,
                      status: _resolveStatus(i),
                      icon: steps[i].icon,
                    ),
                    if (i != steps.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: _resolveStatus(i + 1) == UiStepStatus.wait
                                ? colors.border
                                : colors.brand,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: UiSpacing.md),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i == steps.length - 1 ? 0 : UiSpacing.lg,
                    ),
                    child: GestureDetector(
                      onTap: onStepTapped == null ? null : () => onStepTapped!(i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].title,
                            style: typography.headline.copyWith(
                              color: _resolveStatus(i) == UiStepStatus.wait
                                  ? colors.textSecondary
                                  : colors.textPrimary,
                              fontWeight: _resolveStatus(i) ==
                                      UiStepStatus.process
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                          if (steps[i].description != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                steps[i].description!,
                                style: typography.subheadline.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
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

class _Node extends StatelessWidget {
  const _Node({
    required this.index,
    required this.status,
    required this.icon,
  });

  final int index;
  final UiStepStatus status;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;

    late final Color bg;
    late final Color fg;
    late final Color border;
    Widget? child;

    switch (status) {
      case UiStepStatus.wait:
        bg = colors.surface;
        fg = colors.textTertiary;
        border = colors.border;
        child = Text(
          '${index + 1}',
          style: typography.subheadline
              .copyWith(color: fg, fontWeight: FontWeight.w600),
        );
        break;
      case UiStepStatus.process:
        bg = colors.brand;
        fg = colors.textOnBrand;
        border = colors.brand;
        child = Text(
          '${index + 1}',
          style: typography.subheadline
              .copyWith(color: fg, fontWeight: FontWeight.w700),
        );
        break;
      case UiStepStatus.done:
        bg = colors.brand;
        fg = colors.textOnBrand;
        border = colors.brand;
        child = Icon(icon ?? Icons.check_rounded, size: 16, color: fg);
        break;
      case UiStepStatus.error:
        bg = colors.danger;
        fg = colors.textOnBrand;
        border = colors.danger;
        child = Icon(icon ?? Icons.close_rounded, size: 16, color: fg);
        break;
    }

    return AnimatedContainer(
      duration: UiDuration.base,
      curve: UiCurves.standard,
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.5),
        boxShadow: status == UiStepStatus.process
            ? [
                BoxShadow(
                  color: border.withValues(alpha: 0.25),
                  blurRadius: 0,
                  spreadRadius: 3,
                )
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.active, required this.colors});
  final bool active;
  final UiColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: active ? colors.brand : colors.border,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

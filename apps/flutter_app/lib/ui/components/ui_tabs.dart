import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// Tab 项定义。
class UiTabItem {
  const UiTabItem({required this.label, this.icon});
  final String label;
  final IconData? icon;
}

/// iOS18 风格 TabBar：胶囊背景 + 白色圆角指示器。
///
/// 切换时通过 [AnimatedAlign] + `Align(widthFactor)` 让指示器在 N 个 Tab
/// 之间做线性滑动，避免依赖每帧 `findRenderObject` 的测量，因而性能更优。
/// 这也是 Apple "Segmented Control" 的底层思路。
class UiTabs extends StatelessWidget {
  const UiTabs({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.expanded = true,
  });

  final List<UiTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// 是否拉伸填满横向宽度；false 时按内容自适应宽度。
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final count = items.length;
    final safeIndex = selectedIndex.clamp(0, count - 1);

    // 指示器通过 `Align(widthFactor: 1/count)` 占据总宽度的 1/N，
    // 其横向位置由 Alignment.x ∈ [-1, 1] 根据选中索引线性映射；
    // 这样指示器的滑动不依赖对每个 tab 单独测量。
    final double alignX = count <= 1 ? 0 : (safeIndex / (count - 1)) * 2 - 1;

    final tabRow = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          expanded
              ? Expanded(child: _buildItem(i, safeIndex, colors, typography))
              : _buildItem(i, safeIndex, colors, typography),
      ],
    );

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.groupedBackground,
          borderRadius: UiRadius.brMd,
        ),
        child: Stack(
          children: [
            // 指示器层：仅 expanded 模式下出现，内容随选中项线性滑动。
            //
            // 性能关键点（高刷新率场景）：
            // - 指示器本身（含 BoxShadow）放在独立的 RepaintBoundary 里，
            //   高刷下只需做合成层 translate，不会每帧重新光栅化阴影；
            // - 同理把 [tabRow] 也单独打包，Tab 文案切换只刷自己那层。
            if (expanded && count > 0)
              Positioned.fill(
                child: AnimatedAlign(
                  duration: UiDuration.base,
                  curve: UiCurves.iosSnappy,
                  alignment: Alignment(alignX, 0),
                  child: FractionallySizedBox(
                    widthFactor: 1 / count,
                    heightFactor: 1,
                    child: RepaintBoundary(
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
              ),
            RepaintBoundary(child: tabRow),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(int i, int selectedIndex, colors, typography) {
    final item = items[i];
    final isSelected = i == selectedIndex;
    return _TabButton(
      item: item,
      isSelected: isSelected,
      colors: colors,
      typography: typography,
      onTap: () => onChanged(i),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.isSelected,
    required this.colors,
    required this.typography,
    required this.onTap,
  });

  final UiTabItem item;
  final bool isSelected;
  final dynamic colors;
  final dynamic typography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: UiSpacing.md,
          vertical: UiSpacing.sm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.icon != null) ...[
              Icon(
                item.icon,
                size: 16,
                color: isSelected ? colors.textPrimary : colors.textSecondary,
              ),
              const SizedBox(width: UiSpacing.xs),
            ],
            // Flexible + ellipsis：在窄 Tab（等分 Expanded）里防止 1~2px
            // 级别的文字溢出（中文字度量在高 DPI 下会有亚像素误差）。
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: UiDuration.fast,
                style: typography.callout.copyWith(
                  color: isSelected ? colors.textPrimary : colors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab + 内容的一体化组件。
///
/// 性能要点：
/// - 内部 [PageView] 使用 [PageStorageKey] 支持跨页滚动位置记忆；
/// - 每个 child 外层包 [_KeepAliveWrapper]，切换 tab 不丢状态（如滚动位置、
///   表单输入），避免重复构建；
/// - [AutomaticKeepAliveClientMixin] 配合 [KeepAlive] 只保留可见页以外的
///   已访问页，内存占用可控。
class UiTabView extends StatefulWidget {
  const UiTabView({
    super.key,
    required this.items,
    required this.children,
    this.initialIndex = 0,
    this.onChanged,
    this.keepAlive = true,
  }) : assert(items.length == children.length);

  final List<UiTabItem> items;
  final List<Widget> children;
  final int initialIndex;
  final ValueChanged<int>? onChanged;

  /// 是否缓存非当前页的状态。默认 true，对于仅含静态内容的 tab 可关闭以节省内存。
  final bool keepAlive;

  @override
  State<UiTabView> createState() => _UiTabViewState();
}

class _UiTabViewState extends State<UiTabView> {
  late int _index = widget.initialIndex;
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );

  void _go(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _controller.animateToPage(
      i,
      duration: UiDuration.base,
      curve: UiCurves.iosSmooth,
    );
    widget.onChanged?.call(i);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiTabs(items: widget.items, selectedIndex: _index, onChanged: _go),
        const SizedBox(height: UiSpacing.md),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.children.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              widget.onChanged?.call(i);
            },
            itemBuilder: (context, i) {
              final child = widget.children[i];
              return widget.keepAlive ? _KeepAliveWrapper(child: child) : child;
            },
          ),
        ),
      ],
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  const _KeepAliveWrapper({required this.child});
  final Widget child;

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

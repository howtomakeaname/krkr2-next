import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// 高性能虚拟列表。
///
/// 支持两种典型场景：
///
/// **A. 固定行高（强烈推荐）**
/// ```dart
/// UiVirtualList(items: data, itemExtent: 56, itemBuilder: ...);
/// ```
/// 提供 [itemExtent] 后，Flutter 可以跳过 child 的 intrinsic 测算，滚动时
/// 帧耗时最低，适合 IM 列表、消息流、表格等。
///
/// **B. 变行高**
/// ```dart
/// UiVirtualList(items: data, estimatedItemExtent: 72, itemBuilder: ...);
/// ```
/// 不传 [itemExtent]；可通过 [estimatedItemExtent] 或 [prototypeItem] 给
/// Flutter 一个 **估算值**，用于快速计算 scrollExtent；真实高度仍按子树
/// intrinsic 布局。若两者都不传，行为退化为普通 `ListView.builder`。
///
/// 共同优化：
/// - 每个 item 单独 [RepaintBoundary]，避免单行按压/动画波及整列；
/// - 关闭默认 `addAutomaticKeepAlives` 与 `addRepaintBoundaries`，由我们
///   接管，减少内存占用；
/// - [cacheExtent] 默认扩大到 600px，防止快速滚动白屏。
class UiVirtualList<T> extends StatelessWidget {
  const UiVirtualList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.separator = true,
    this.itemExtent,
    this.estimatedItemExtent,
    this.prototypeItem,
    this.padding,
    this.controller,
    this.physics,
    this.cacheExtent = 600,
    this.shrinkWrap = false,
    this.findChildIndexCallback,
    this.itemKeyBuilder,
  })  : assert(!(itemExtent != null && separator),
            'itemExtent 为固定高度场景，无法叠加分割线高度；请关闭 separator'),
        assert(!(itemExtent != null && prototypeItem != null),
            'itemExtent 与 prototypeItem 只能二选一');

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// 是否在行之间显示 0.6px 分隔线（仅变行高场景下生效）。
  final bool separator;

  /// 固定行高（推荐）。
  final double? itemExtent;

  /// 估算行高。仅在 [itemExtent] 为空时生效；提升滚动条位置估算精度。
  final double? estimatedItemExtent;

  /// 原型 widget。若提供，Flutter 会以它的真实尺寸作为估算高度。
  /// 与 [itemExtent] 互斥。
  final Widget? prototypeItem;

  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final double cacheExtent;
  final bool shrinkWrap;

  /// 当列表 items 顺序会变化（插入/删除/排序）时，提供一个稳定的 key
  /// 可以让 Flutter 精准复用已测算好的 sliver child，有显著性能提升。
  final int? Function(Key key)? findChildIndexCallback;

  /// 可选：为每个 item 生成稳定 Key（配合 [findChildIndexCallback] 使用）。
  final Key Function(T item, int index)? itemKeyBuilder;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    // === 固定行高分支 ===
    if (itemExtent != null) {
      return ListView.builder(
        controller: controller,
        physics: physics,
        padding: padding,
        cacheExtent: cacheExtent,
        shrinkWrap: shrinkWrap,
        itemCount: items.length,
        itemExtent: itemExtent,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false,
        addSemanticIndexes: true,
        findChildIndexCallback: findChildIndexCallback,
        itemBuilder: (ctx, i) => _wrap(i, itemBuilder(ctx, items[i], i)),
      );
    }

    // === 变行高分支 ===
    if (separator) {
      return ListView.separated(
        controller: controller,
        physics: physics,
        padding: padding,
        cacheExtent: cacheExtent,
        shrinkWrap: shrinkWrap,
        itemCount: items.length,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false,
        findChildIndexCallback: findChildIndexCallback,
        separatorBuilder: (_, __) => Divider(
          height: 0.6,
          thickness: 0.6,
          color: colors.separator,
          indent: UiSpacing.lg,
        ),
        itemBuilder: (ctx, i) => _wrap(i, itemBuilder(ctx, items[i], i)),
      );
    }

    // 无分隔线：使用 prototypeItem 或估算高度做 scroll extent 优化。
    return ListView.builder(
      controller: controller,
      physics: physics,
      padding: padding,
      cacheExtent: cacheExtent,
      shrinkWrap: shrinkWrap,
      itemCount: items.length,
      prototypeItem: prototypeItem ??
          (estimatedItemExtent != null
              ? SizedBox(height: estimatedItemExtent)
              : null),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      findChildIndexCallback: findChildIndexCallback,
      itemBuilder: (ctx, i) => _wrap(i, itemBuilder(ctx, items[i], i)),
    );
  }

  Widget _wrap(int i, Widget child) {
    final key = itemKeyBuilder?.call(items[i], i);
    return RepaintBoundary(
      key: key,
      child: child,
    );
  }
}

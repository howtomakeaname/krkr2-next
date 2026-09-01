import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// iOS 风格大标题导航栏。
///
/// 基于 [SliverPersistentHeader]：未滚动时显示大标题（28pt），随着内容上
/// 滚，大标题淡出并缩放到导航栏中央形成紧凑小标题；达到阈值后会出现底部
/// 分隔线与毛玻璃底。必须作为 [CustomScrollView] 的首个 sliver 使用。
///
/// 典型用法：
/// ```dart
/// CustomScrollView(
///   slivers: [
///     UiAppBar.sliver(title: 'iOS 18', actions: [...]),
///     SliverList(...),
///   ],
/// )
/// ```
class UiAppBar extends StatelessWidget {
  const UiAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.collapsedHeight = 44,
    this.expandedHeight = 96,
    this.blur = true,
    this.largeTitlePadding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });

  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final double collapsedHeight;
  final double expandedHeight;
  final bool blur;
  final EdgeInsets largeTitlePadding;

  /// 快捷方法：直接返回可塞入 slivers 的 [SliverPersistentHeader]。
  static Widget sliver({
    Key? key,
    required String title,
    Widget? leading,
    List<Widget>? actions,
    double collapsedHeight = 44,
    double expandedHeight = 96,
    bool blur = true,
    EdgeInsets largeTitlePadding =
        const EdgeInsets.fromLTRB(16, 0, 16, 12),
  }) {
    return SliverPersistentHeader(
      pinned: true,
      floating: false,
      delegate: _UiAppBarDelegate(
        title: title,
        leading: leading,
        actions: actions,
        collapsedHeight: collapsedHeight,
        expandedHeight: expandedHeight,
        blur: blur,
        largeTitlePadding: largeTitlePadding,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 允许独立作为 Scaffold.appBar 使用时退化为紧凑版。
    final colors = context.uiColors;
    final typography = context.uiType;
    return Container(
      height: collapsedHeight,
      color: colors.background,
      padding: const EdgeInsets.symmetric(horizontal: UiSpacing.sm),
      child: NavigationToolbar(
        leading: leading,
        middle: Text(
          title,
          style: typography.headline.copyWith(color: colors.textPrimary),
        ),
        trailing: actions == null
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: actions!),
        centerMiddle: true,
      ),
    );
  }
}

class _UiAppBarDelegate extends SliverPersistentHeaderDelegate {
  _UiAppBarDelegate({
    required this.title,
    required this.leading,
    required this.actions,
    required this.collapsedHeight,
    required this.expandedHeight,
    required this.blur,
    required this.largeTitlePadding,
  });

  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final double collapsedHeight;
  final double expandedHeight;
  final bool blur;
  final EdgeInsets largeTitlePadding;

  @override
  double get minExtent => collapsedHeight;

  @override
  double get maxExtent => collapsedHeight + expandedHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final colors = context.uiColors;
    final typography = context.uiType;

    final range = maxExtent - minExtent;
    final t = (shrinkOffset / range).clamp(0.0, 1.0);

    // 大标题透明度：在 0..0.6 段快速淡出。
    final largeOpacity = (1 - t / 0.6).clamp(0.0, 1.0);
    // 小标题（导航栏中央）淡入：在 0.5..1 段出现。
    final compactOpacity = ((t - 0.5) / 0.5).clamp(0.0, 1.0);

    // 折叠时底部分隔线与背景不透明度。
    final bgOpacity = t;

    Widget bg = ColoredBox(color: colors.background.withValues(alpha: bgOpacity));
    if (blur && bgOpacity > 0.05) {
      bg = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: ColoredBox(
          color: colors.background.withValues(alpha: 0.75 * bgOpacity + 0.05),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: bg),
        // 顶部紧凑区域：leading / title / actions。
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: collapsedHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: UiSpacing.sm),
            child: NavigationToolbar(
              leading: leading,
              middle: Opacity(
                opacity: compactOpacity,
                child: Text(
                  title,
                  style: typography.headline.copyWith(color: colors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              trailing: actions == null
                  ? null
                  : Row(mainAxisSize: MainAxisSize.min, children: actions!),
              centerMiddle: true,
            ),
          ),
        ),
        // 大标题：放在紧凑区域下方，滚动时整体淡出。
        Positioned(
          left: 0,
          right: 0,
          top: collapsedHeight,
          bottom: 0,
          child: IgnorePointer(
            child: Opacity(
              opacity: largeOpacity,
              child: Padding(
                padding: largeTitlePadding,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    title,
                    style: typography.largeTitle
                        .copyWith(color: colors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
        // 底部分隔线：折叠后才显示。
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 0.5,
          child: Opacity(
            opacity: t > 0.95 ? 1 : 0,
            child: ColoredBox(color: colors.separator),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _UiAppBarDelegate old) {
    return title != old.title ||
        leading != old.leading ||
        actions != old.actions ||
        collapsedHeight != old.collapsedHeight ||
        expandedHeight != old.expandedHeight ||
        blur != old.blur;
  }
}

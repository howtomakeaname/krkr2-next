import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../theme/ui_glass_theme.dart';
import '../theme/ui_metrics.dart';
import '../theme/ui_springs.dart';
import '../theme/ui_theme.dart';
import 'ui_badge.dart';
import 'ui_glass.dart';

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

/// iOS 26 风格的悬浮 Liquid Glass tab bar。
///
/// 整栏只采样一次背景；选中态是一枚在同一材质面内移动的透镜。透镜位置由
/// [SpringSimulation] 驱动并保留当前速度，所以连续切换不会让动画跳回起点。
class UiNavBar extends StatefulWidget {
  const UiNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    this.backgroundColor,
    this.showLabel = true,
    this.enableHaptic = true,
    this.overMedia = false,
  }) : assert(items.length >= 2),
       assert(currentIndex >= 0 && currentIndex < items.length);

  final List<UiNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  /// 兼容旧调用。Liquid Glass 模式下作为选中图标与文字的强调色。
  final Color? backgroundColor;
  final bool showLabel;
  final bool enableHaptic;

  /// Uses the high-contrast glass appearance when artwork scrolls below the
  /// bar. Native Liquid Glass adapts in the same direction over media.
  final bool overMedia;

  @override
  State<UiNavBar> createState() => _UiNavBarState();
}

class _UiNavBarState extends State<UiNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _selection = AnimationController.unbounded(
    vsync: this,
    value: widget.currentIndex.toDouble(),
  );

  bool get _reduceMotion {
    final mediaQuery = MediaQuery.maybeOf(context);
    return mediaQuery?.disableAnimations ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
  }

  @override
  void didUpdateWidget(covariant UiNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex == widget.currentIndex) return;
    if (_reduceMotion) {
      _selection.value = widget.currentIndex.toDouble();
      return;
    }
    _selection.animateWith(
      SpringSimulation(
        UiSprings.materialize,
        _selection.value,
        widget.currentIndex.toDouble(),
        _selection.velocity,
      ),
    );
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final materialIsDark = isDark || widget.overMedia;
    final tint = widget.backgroundColor ?? colors.brand;
    final barHeight = widget.showLabel ? 54.0 : 48.0;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 286),
            child: SizedBox(
              key: const ValueKey<String>('ui-nav-glass'),
              height: barHeight + 4,
              child: UiGlassSurface(
                variant: UiGlassVariant.clear,
                borderRadius: UiRadius.brPill,
                padding: EdgeInsets.zero,
                // A small amount of diffusion keeps fine image detail from
                // fighting the controls. The glass character comes from the
                // displaced rim and highlights below, not from this blur.
                enableBlur: true,
                blurScale: 0.24,
                showBorder: false,
                showShadow: false,
                showRefraction: false,
                materialStrength: widget.overMedia
                    ? 0.22
                    : (isDark ? 0.72 : 0.58),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const Positioned.fill(child: _NavRefractionRim()),
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: UiDuration.fast,
                        curve: UiSprings.materializeCurve,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: widget.overMedia
                                ? const <Color>[
                                    Color(0x52141416),
                                    Color(0x42141416),
                                    Color(0x5C08080A),
                                  ]
                                : const <Color>[
                                    Colors.transparent,
                                    Colors.transparent,
                                    Colors.transparent,
                                  ],
                            stops: const <double>[0, 0.58, 1],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(3),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final itemWidth =
                              constraints.maxWidth / widget.items.length;
                          return AnimatedBuilder(
                            animation: _selection,
                            builder: (context, _) {
                              final maxIndex = widget.items.length - 1.0;
                              final position = _selection.value.clamp(
                                -0.08,
                                maxIndex + 0.08,
                              );
                              final lensInset = widget.showLabel ? 7.0 : 5.0;
                              final lensStretch =
                                  (_selection.velocity.abs() * 1.8).clamp(
                                    0.0,
                                    9.0,
                                  );
                              return Stack(
                                fit: StackFit.expand,
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  Positioned(
                                    left:
                                        position * itemWidth +
                                        lensInset -
                                        lensStretch / 2,
                                    top: 3,
                                    width:
                                        itemWidth - lensInset * 2 + lensStretch,
                                    bottom: 3,
                                    child: _SelectionLens(
                                      key: ValueKey<String>(
                                        'ui-nav-selection-lens',
                                      ),
                                      isDark: materialIsDark,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      for (
                                        var i = 0;
                                        i < widget.items.length;
                                        i++
                                      )
                                        Expanded(
                                          child: _NavButton(
                                            key: ValueKey<String>(
                                              'ui-nav-item-$i',
                                            ),
                                            item: widget.items[i],
                                            selected: i == widget.currentIndex,
                                            showLabel: widget.showLabel,
                                            activeColor: tint,
                                            darkMaterial: materialIsDark,
                                            onTap: () {
                                              if (i == widget.currentIndex) {
                                                return;
                                              }
                                              if (widget.enableHaptic) {
                                                HapticFeedback.selectionClick();
                                              }
                                              widget.onChanged(i);
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _NavOpticalEdgePainter(
                            isDark: materialIsDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionLens extends StatelessWidget {
  const _SelectionLens({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final glass = context.uiGlass;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          const scaleX = 1.045;
          const scaleY = 1.08;
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final matrix = Float64List.fromList(<double>[
            scaleX,
            0,
            0,
            0,
            0,
            scaleY,
            0,
            0,
            0,
            0,
            1,
            0,
            width * (1 - scaleX) / 2,
            height * (1 - scaleY) / 2,
            0,
            1,
          ]);
          return ClipRRect(
            borderRadius: UiRadius.brPill,
            child: BackdropFilter(
              filter: ImageFilter.matrix(
                matrix,
                filterQuality: FilterQuality.medium,
              ),
              child: CustomPaint(
                painter: _SelectionLensPainter(isDark: isDark),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: UiRadius.brPill,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? <Color>[
                              glass.highlight.withValues(alpha: 0.11),
                              const Color(0x08FFFFFF),
                              const Color(0x24000000),
                            ]
                          : const <Color>[
                              Color(0x29FFFFFF),
                              Color(0x0DFFFFFF),
                              Color(0x0A000000),
                            ],
                      stops: const <double>[0, 0.56, 1],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SelectionLensPainter extends CustomPainter {
  const _SelectionLensPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.65);
    final radius = Radius.circular(size.height / 2);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const <Color>[
                Color(0x52FFFFFF),
                Color(0x1FFFFFFF),
                Color(0x24000000),
              ]
            : const <Color>[
                Color(0x8CFFFFFF),
                Color(0x1FFFFFFF),
                Color(0x19000000),
              ],
        stops: const <double>[0, 0.60, 1],
      ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), edge);
  }

  @override
  bool shouldRepaint(covariant _SelectionLensPainter oldDelegate) =>
      isDark != oldDelegate.isDark;
}

/// 只在外缘窄环带重新采样背景。中心保持清晰透射，不使用高斯模糊。
class _NavRefractionRim extends StatelessWidget {
  const _NavRefractionRim();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        const scaleX = 1.025;
        const scaleY = 1.10;
        final matrix = Float64List.fromList(<double>[
          scaleX,
          0,
          0,
          0,
          0,
          scaleY,
          0,
          0,
          0,
          0,
          1,
          0,
          width * (1 - scaleX) / 2,
          height * (1 - scaleY) / 2,
          0,
          1,
        ]);
        return ClipPath(
          clipper: const _NavRimClipper(thickness: 5),
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.matrix(
              matrix,
              filterQuality: FilterQuality.medium,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _NavRimClipper extends CustomClipper<Path> {
  const _NavRimClipper({required this.thickness});

  final double thickness;

  @override
  Path getClip(Size size) {
    final rect = Offset.zero & size;
    final outer = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2)),
      );
    final innerRect = rect.deflate(thickness);
    final inner = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          innerRect,
          Radius.circular(size.height / 2 - thickness),
        ),
      );
    return Path.combine(PathOperation.difference, outer, inner);
  }

  @override
  bool shouldReclip(covariant _NavRimClipper oldClipper) =>
      thickness != oldClipper.thickness;
}

/// 非均匀明暗边缘用于模拟玻璃厚度；不画整圈白边，避免塑料胶囊感。
class _NavOpticalEdgePainter extends CustomPainter {
  const _NavOpticalEdgePainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final edgeRect = rect.deflate(0.7);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const <Color>[
                Color(0x94FFFFFF),
                Color(0x2BFFFFFF),
                Color(0x1FFFFFFF),
              ]
            : const <Color>[
                Color(0x70FFFFFF),
                Color(0x20FFFFFF),
                Color(0x14000000),
              ],
        stops: const <double>[0, 0.48, 1],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(edgeRect, Radius.circular(size.height / 2)),
      edge,
    );
  }

  @override
  bool shouldRepaint(covariant _NavOpticalEdgePainter oldDelegate) =>
      isDark != oldDelegate.isDark;
}

class _NavButton extends StatefulWidget {
  const _NavButton({
    super.key,
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.activeColor,
    required this.darkMaterial,
    required this.onTap,
  });

  final UiNavItem item;
  final bool selected;
  final bool showLabel;
  final Color activeColor;
  final bool darkMaterial;
  final VoidCallback onTap;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  void _animatePress(double target) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _press.value = target;
      return;
    }
    _press.animateWith(
      SpringSimulation(UiSprings.press, _press.value, target, _press.velocity),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final active = widget.selected
        ? widget.activeColor
        : widget.darkMaterial
        ? Colors.white.withValues(alpha: 0.82)
        : colors.textPrimary.withValues(alpha: 0.78);
    final icon = Icon(
      widget.selected
          ? (widget.item.activeIcon ?? widget.item.icon)
          : widget.item.icon,
      size: widget.showLabel ? 21 : 23,
      color: active,
    );
    final badged =
        (widget.item.badgeDot ||
            (widget.item.badgeCount != null && widget.item.badgeCount! > 0))
        ? UiBadge(
            dot: widget.item.badgeDot,
            count: widget.item.badgeCount,
            offset: const Offset(4, -4),
            child: icon,
          )
        : icon;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _animatePress(1),
        onTapCancel: () => _animatePress(0),
        onTapUp: (_) => _animatePress(0),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, child) {
            final progress = _press.value.clamp(0.0, 1.0);
            return Transform.scale(
              scale: 1 - progress * 0.065,
              child: Opacity(opacity: 1 - progress * 0.12, child: child),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                badged,
                if (widget.showLabel) ...[
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: UiDuration.fast,
                    curve: UiSprings.materializeCurve,
                    style: typography.caption.copyWith(
                      color: active,
                      fontSize: 10.5,
                      height: 1.15,
                      fontWeight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                    child: Text(
                      widget.item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

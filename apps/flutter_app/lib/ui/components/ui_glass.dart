import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../theme/ui_glass_theme.dart';
import '../theme/ui_metrics.dart';
import '../theme/ui_springs.dart';
import '../theme/ui_theme.dart';

/// 玻璃材质的视觉密度。
enum UiGlassVariant {
  /// 小型、临时控件；让更多背景内容透出。
  clear,

  /// 工具栏、菜单、Sheet；优先保证内容可读性。
  regular,
}

/// Liquid Glass 功能层的基础容器。
///
/// [enableBlur] 可在游戏画面或性能敏感场景关闭。关闭后仍保留统一的染色、
/// 高光、描边和阴影，因此视觉层级不会退化成普通透明矩形。
class UiGlassSurface extends StatelessWidget {
  const UiGlassSurface({
    super.key,
    required this.child,
    this.variant = UiGlassVariant.regular,
    this.padding = EdgeInsets.zero,
    this.borderRadius = UiRadius.brPill,
    this.tint,
    this.enableBlur,
    this.showShadow = true,
    this.interaction = 0,
  });

  final Widget child;
  final UiGlassVariant variant;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  /// 可选语义色。组件会控制混合强度，调用侧不需要手调透明度。
  final Color? tint;

  /// null 时按平台选择：HarmonyOS 使用稳定的无 blur 材质，其他平台启用。
  final bool? enableBlur;
  final bool showShadow;

  /// 0 为静止，1 为按下。按下时材质会略微提亮。
  final double interaction;

  @override
  Widget build(BuildContext context) {
    final glass = context.uiGlass;
    final progress = interaction.clamp(0.0, 1.0);
    final baseFill = switch (variant) {
      UiGlassVariant.clear => glass.clearFill,
      UiGlassVariant.regular => glass.regularFill,
    };
    final blurSigma = switch (variant) {
      UiGlassVariant.clear => glass.clearBlurSigma,
      UiGlassVariant.regular => glass.regularBlurSigma,
    };

    var fill = Color.alphaBlend(
      glass.pressedFill.withValues(alpha: glass.pressedFill.a * progress),
      baseFill,
    );
    if (tint case final color?) {
      final strength = variant == UiGlassVariant.clear ? 0.13 : 0.18;
      fill = Color.alphaBlend(color.withValues(alpha: strength), fill);
    }

    final borderColor = tint == null
        ? glass.border
        : Color.lerp(glass.border, tint, 0.18)!;
    final highlight = glass.highlight.withValues(
      alpha: glass.highlight.a * (0.72 + 0.28 * progress),
    );

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              highlight.withValues(alpha: highlight.a * 0.22),
              fill,
            ),
            fill,
            Color.alphaBlend(Colors.black.withValues(alpha: 0.035), fill),
          ],
          stops: const <double>[0, 0.48, 1],
        ),
        border: Border.all(color: borderColor, width: 0.8),
        borderRadius: borderRadius,
      ),
      child: Padding(padding: padding, child: child),
    );

    final blurEnabled = enableBlur ?? Theme.of(context).platform.name != 'ohos';
    if (blurEnabled && blurSigma > 0) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: surface,
      );
    }

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: showShadow
              ? <BoxShadow>[
                  BoxShadow(
                    color: glass.shadow,
                    blurRadius: variant == UiGlassVariant.clear ? 18 : 28,
                    offset: const Offset(0, 8),
                    spreadRadius: -6,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
          child: surface,
        ),
      ),
    );
  }
}

/// 一组共享同一块玻璃的工具栏控件。
///
/// 相邻按钮必须共用一个材质采样面，既符合 Liquid Glass 的单层原则，也避免
/// 多个 BackdropFilter 重叠带来的额外合成开销。
class UiGlassToolbar extends StatelessWidget {
  const UiGlassToolbar({
    super.key,
    required this.children,
    this.variant = UiGlassVariant.clear,
    this.tint,
    this.enableBlur,
    this.padding = const EdgeInsets.all(2),
  }) : assert(children.length > 0);

  final List<Widget> children;
  final UiGlassVariant variant;
  final Color? tint;
  final bool? enableBlur;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return UiGlassSurface(
      variant: variant,
      tint: tint,
      enableBlur: enableBlur,
      padding: padding,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Liquid Glass 图标按钮。
///
/// 按下和松开均由物理弹簧驱动，并继承当前速度；快速连续点击不会在中途跳帧。
class UiGlassIconButton extends StatefulWidget {
  const UiGlassIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.onLongPress,
    this.size = UiNavigationMetrics.buttonExtent,
    this.iconSize = UiNavigationMetrics.iconSize,
    this.foregroundColor,
    this.tint,
    this.variant = UiGlassVariant.clear,
    this.contained = true,
    this.enableBlur,
    this.enableHaptic = true,
    this.loading = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final double size;
  final double iconSize;
  final Color? foregroundColor;
  final Color? tint;
  final UiGlassVariant variant;

  /// false 时作为 [UiGlassToolbar] 的子项，不再创建第二层玻璃。
  final bool contained;
  final bool? enableBlur;
  final bool enableHaptic;
  final bool loading;

  @override
  State<UiGlassIconButton> createState() => _UiGlassIconButtonState();
}

class _UiGlassIconButtonState extends State<UiGlassIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  bool get _enabled => widget.onPressed != null && !widget.loading;

  bool get _reduceMotion {
    final mediaQuery = MediaQuery.maybeOf(context);
    return mediaQuery?.disableAnimations ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
  }

  void _animateTo(double target) {
    if (_reduceMotion) {
      _press.value = target;
      return;
    }
    _press.animateWith(
      SpringSimulation(UiSprings.press, _press.value, target, _press.velocity),
    );
  }

  void _handleTapDown(TapDownDetails _) {
    if (_enabled) _animateTo(1);
  }

  void _handleTapCancel() => _animateTo(0);

  void _handleTapUp(TapUpDetails _) => _animateTo(0);

  void _handleTap() {
    if (!_enabled) return;
    if (widget.enableHaptic) HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  @override
  void didUpdateWidget(covariant UiGlassIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_enabled != (oldWidget.onPressed != null && !oldWidget.loading)) {
      _animateTo(0);
    }
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.foregroundColor ?? context.uiColors.brand;
    final child = SizedBox.square(
      dimension: widget.size,
      child: Center(
        child: widget.loading
            ? SizedBox.square(
                dimension: widget.iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : Icon(widget.icon, size: widget.iconSize, color: foreground),
      ),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapCancel: _handleTapCancel,
        onTapUp: _handleTapUp,
        onTap: _enabled ? _handleTap : null,
        onLongPress: _enabled ? widget.onLongPress : null,
        child: AnimatedBuilder(
          animation: _press,
          child: child,
          builder: (context, child) {
            final progress = _press.value.clamp(0.0, 1.0);
            final content = Transform.scale(
              scale: 1 - 0.055 * progress,
              child: Opacity(opacity: _enabled ? 1 : 0.42, child: child),
            );
            if (!widget.contained) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: context.uiGlass.pressedFill.withValues(
                    alpha: context.uiGlass.pressedFill.a * progress,
                  ),
                  borderRadius: UiRadius.brPill,
                ),
                child: content,
              );
            }
            return UiGlassSurface(
              variant: widget.variant,
              tint: widget.tint,
              enableBlur: widget.enableBlur,
              interaction: progress,
              child: content,
            );
          },
        ),
      ),
    );
  }
}

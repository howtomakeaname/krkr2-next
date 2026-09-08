import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/cupertino.dart' show CupertinoTheme, CupertinoThemeData;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as glass;

import '../theme/ui_glass_theme.dart';
import '../theme/ui_metrics.dart';
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
/// [enableBlur] 可在游戏画面或性能敏感场景显式关闭。普通界面默认启用真实
/// 背景采样；关闭后仍保留统一的染色、高光、描边和阴影。
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
    this.showBorder = true,
    this.showRefraction = true,
    this.materialStrength = 1,
    this.blurScale = 1,
    this.interaction = 0,
  }) : assert(materialStrength >= 0 && materialStrength <= 1),
       assert(blurScale >= 0);

  final Widget child;
  final UiGlassVariant variant;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  /// 可选语义色。组件会控制混合强度，调用侧不需要手调透明度。
  final Color? tint;

  /// null 时启用。游戏画面等持续高频渲染区域应显式传 false。
  final bool? enableBlur;
  final bool showShadow;
  final bool showBorder;
  final bool showRefraction;

  /// 材质染色强度。导航浮岛等需要保留更多背景细节的控件可适当降低。
  final double materialStrength;

  /// 背景采样模糊倍率。只改变模糊半径，不改变材质染色。
  final double blurScale;

  /// 0 为静止，1 为按下。按下时材质会略微提亮。
  final double interaction;

  @override
  Widget build(BuildContext context) {
    final glass = context.uiGlass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedRadius = borderRadius.resolve(Directionality.of(context));
    final progress = interaction.clamp(0.0, 1.0);
    final rawFill = switch (variant) {
      UiGlassVariant.clear => glass.clearFill,
      UiGlassVariant.regular => glass.regularFill,
    };
    final baseFill = rawFill.withValues(alpha: rawFill.a * materialStrength);
    final blurSigma =
        switch (variant) {
          UiGlassVariant.clear => glass.clearBlurSigma,
          UiGlassVariant.regular => glass.regularBlurSigma,
        } *
        blurScale;

    var fill = Color.alphaBlend(
      glass.pressedFill.withValues(
        alpha: glass.pressedFill.a * progress * materialStrength,
      ),
      baseFill,
    );
    if (tint case final color?) {
      final strength =
          (variant == UiGlassVariant.clear ? 0.13 : 0.18) * materialStrength;
      fill = Color.alphaBlend(color.withValues(alpha: strength), fill);
    }

    final borderColor = tint == null
        ? glass.border
        : Color.lerp(glass.border, tint, 0.18)!;
    final highlight = glass.highlight.withValues(
      alpha: glass.highlight.a * (0.72 + 0.28 * progress) * materialStrength,
    );

    final material = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              highlight.withValues(alpha: highlight.a * 0.18),
              fill,
            ),
            fill,
            Color.alphaBlend(
              Colors.black.withValues(alpha: 0.045 * materialStrength),
              fill,
            ),
          ],
          stops: const <double>[0, 0.52, 1],
        ),
        borderRadius: borderRadius,
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: RadialGradient(
            center: const Alignment(-0.72, -1.08),
            radius: 1.1,
            colors: <Color>[
              highlight.withValues(alpha: highlight.a * 0.18),
              highlight.withValues(alpha: 0),
            ],
            stops: const <double>[0, 0.72],
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );

    final blurEnabled = enableBlur ?? true;
    Widget surface = Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        if (blurEnabled && showRefraction)
          Positioned.fill(
            child: _GlassRefractionRim(
              borderRadius: resolvedRadius,
              thickness: variant == UiGlassVariant.clear ? 3.2 : 2.6,
              scaleX: variant == UiGlassVariant.clear ? 1.024 : 1.014,
              scaleY: variant == UiGlassVariant.clear ? 1.055 : 1.030,
            ),
          ),
        material,
      ],
    );
    if (showBorder) {
      surface = CustomPaint(
        foregroundPainter: _GlassOpticalEdgePainter(
          borderRadius: resolvedRadius,
          border: borderColor,
          highlight: glass.highlight,
          isDark: isDark,
        ),
        child: surface,
      );
    }
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
                    color: glass.shadow.withValues(
                      alpha: glass.shadow.a * 0.58,
                    ),
                    blurRadius: variant == UiGlassVariant.clear ? 12 : 20,
                    offset: const Offset(0, 5),
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

/// Samples a narrow perimeter from a slightly displaced backdrop. The middle
/// remains a normal translucent material; this is what gives the surface an
/// optical edge instead of turning it into a uniformly frosted rectangle.
class _GlassRefractionRim extends StatelessWidget {
  const _GlassRefractionRim({
    required this.borderRadius,
    required this.thickness,
    required this.scaleX,
    required this.scaleY,
  });

  final BorderRadius borderRadius;
  final double thickness;
  final double scaleX;
  final double scaleY;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
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
        return ClipPath(
          clipper: _GlassRimClipper(
            borderRadius: borderRadius,
            thickness: thickness,
          ),
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

class _GlassRimClipper extends CustomClipper<Path> {
  const _GlassRimClipper({required this.borderRadius, required this.thickness});

  final BorderRadius borderRadius;
  final double thickness;

  @override
  Path getClip(Size size) {
    final outer = borderRadius.toRRect(Offset.zero & size);
    final outerPath = Path()..addRRect(outer);
    final innerPath = Path()..addRRect(outer.deflate(thickness));
    return Path.combine(PathOperation.difference, outerPath, innerPath);
  }

  @override
  bool shouldReclip(covariant _GlassRimClipper oldClipper) =>
      borderRadius != oldClipper.borderRadius ||
      thickness != oldClipper.thickness;
}

class _GlassOpticalEdgePainter extends CustomPainter {
  const _GlassOpticalEdgePainter({
    required this.borderRadius,
    required this.border,
    required this.highlight,
    required this.isDark,
  });

  final BorderRadius borderRadius;
  final Color border;
  final Color highlight;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.65);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          highlight.withValues(alpha: highlight.a * 0.72),
          border.withValues(alpha: border.a * 0.52),
          border.withValues(alpha: border.a * 0.18),
          Colors.black.withValues(alpha: isDark ? 0.13 : 0.08),
        ],
        stops: const <double>[0, 0.38, 0.68, 1],
      ).createShader(rect);
    canvas.drawRRect(borderRadius.toRRect(rect), edge);
  }

  @override
  bool shouldRepaint(covariant _GlassOpticalEdgePainter oldDelegate) =>
      borderRadius != oldDelegate.borderRadius ||
      border != oldDelegate.border ||
      highlight != oldDelegate.highlight ||
      isDark != oldDelegate.isDark;
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
    this.interactive = true,
  }) : child = null,
       assert(children.length > 0);

  /// Keeps a changing toolbar body (for example a search field) in one lens.
  const UiGlassToolbar.custom({
    super.key,
    required Widget this.child,
    this.variant = UiGlassVariant.clear,
    this.tint,
    this.enableBlur,
    this.padding = const EdgeInsets.all(2),
    this.interactive = true,
  }) : children = const [];

  final List<Widget> children;
  final Widget? child;
  final UiGlassVariant variant;
  final Color? tint;
  final bool? enableBlur;
  final EdgeInsetsGeometry padding;

  /// Disable deformation while editing text, without replacing the subtree.
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    return _UiGlassControlTheme(
      child: Builder(
        builder: (context) {
          final animate =
              interactive && !MediaQuery.disableAnimationsOf(context);
          return glass.GlassButton.custom(
            // Child controls own activation, focus and semantics.
            onTap: () {},
            canRequestFocus: false,
            excludeFromSemantics: true,
            shape: const glass.LiquidRoundedRectangle(borderRadius: 999),
            useOwnLayer: true,
            quality: _controlQuality(enableBlur),
            settings: _controlSettings(context, variant, tint, enableBlur),
            interactionScale: animate ? 1.025 : 1,
            stretch: animate ? 0.15 : 0,
            glowRadius: animate ? null : 0,
            ambientBaseLight: animate ? _controlPressLight(context) : 0,
            child: Padding(
              padding: padding,
              child:
                  child ??
                  Row(mainAxisSize: MainAxisSize.min, children: children),
            ),
          );
        },
      ),
    );
  }
}

/// Glass optics and anchored stretch come from liquid_glass_widgets.
/// This adapter keeps the app's loading, long-press and haptic behavior.
class UiGlassIconButton extends StatelessWidget {
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

  /// false uses the parent's glass; only the local press highlight is drawn.
  final bool contained;
  final bool? enableBlur;
  final bool enableHaptic;
  final bool loading;

  bool get _enabled => onPressed != null && !loading;

  void _activate() {
    if (!_enabled) return;
    if (enableHaptic) HapticFeedback.lightImpact();
    onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final foreground = foregroundColor ?? context.uiColors.brand;
    return Semantics(
      button: true,
      enabled: _enabled,
      label: semanticLabel,
      onTap: _enabled ? _activate : null,
      onLongPress: _enabled ? onLongPress : null,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: _UiGlassControlTheme(
          child: Builder(
            builder: (context) {
              final reduceMotion = MediaQuery.disableAnimationsOf(context);
              return IgnorePointer(
                ignoring: !_enabled,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onLongPress: _enabled ? onLongPress : null,
                  child: glass.GlassButton.custom(
                    // A loading/disabled transition cancels any held press.
                    key: ValueKey(_enabled),
                    onTap: _activate,
                    enabled: _enabled,
                    canRequestFocus: _enabled,
                    excludeFromSemantics: true,
                    width: size,
                    height: size,
                    shape: const glass.LiquidOval(),
                    style: contained
                        ? glass.GlassButtonStyle.filled
                        : glass.GlassButtonStyle.transparent,
                    useOwnLayer: contained,
                    quality: _controlQuality(enableBlur),
                    settings: _controlSettings(
                      context,
                      variant,
                      tint,
                      enableBlur,
                    ),
                    // The default +17pt growth clips a 44pt button inside a
                    // 56pt app bar. Shared-toolbar children must not scale twice.
                    interactionScale: reduceMotion || !contained ? 1 : 1.06,
                    stretch: reduceMotion || !contained ? 0 : 0.5,
                    glowRadius: reduceMotion ? 0 : null,
                    ambientBaseLight: reduceMotion
                        ? 0
                        : _controlPressLight(context),
                    child: loading
                        ? SizedBox.square(
                            dimension: iconSize,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: foreground,
                            ),
                          )
                        : Icon(icon, size: iconSize, color: foreground),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

double _controlPressLight(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? 0.04 : 0.08;

glass.GlassQuality _controlQuality(bool? enableBlur) => enableBlur == false
    ? glass.GlassQuality.minimal
    : glass.GlassQuality.premium;

glass.LiquidGlassSettings _controlSettings(
  BuildContext context,
  UiGlassVariant variant,
  Color? tint,
  bool? enableBlur,
) {
  final settings =
      glass.GlassThemeData.of(
        context,
      ).settingsFor(context)?.applyTo(const glass.LiquidGlassSettings()) ??
      const glass.LiquidGlassSettings();
  return settings.copyWith(
    glassColor: tint == null
        ? settings.glassColor
        : Color.alphaBlend(tint.withValues(alpha: 0.10), settings.glassColor),
    blur: enableBlur == false
        ? 0
        : variant == UiGlassVariant.regular
        ? math.max(8, settings.blur)
        : settings.blur,
  );
}

/// The app can use a different appearance from the system.
class _UiGlassControlTheme extends StatelessWidget {
  const _UiGlassControlTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: CupertinoThemeData(
        brightness: Theme.of(context).brightness,
        primaryColor: context.uiColors.brand,
      ),
      child: glass.GlassAccessibilityScope(child: child),
    );
  }
}

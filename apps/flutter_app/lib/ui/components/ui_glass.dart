import 'dart:math' as math;
import 'dart:typed_data';
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
    this.shift = Offset.zero,
  });

  final BorderRadius borderRadius;
  final double thickness;
  final double scaleX;
  final double scaleY;
  final Offset shift;

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
          width * (1 - scaleX) / 2 + shift.dx,
          height * (1 - scaleY) / 2 + shift.dy,
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
    with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _pullX = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _pullY = AnimationController.unbounded(
    vsync: this,
  );
  int? _trackedPointer;
  Duration? _lastPointerTime;
  Offset _releaseVelocity = Offset.zero;

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

  void _setPull(Offset localPosition) {
    final center = Offset(widget.size / 2, widget.size / 2);
    var pull = localPosition - center;
    final limit = widget.size * 0.82;
    if (pull.distance > limit) {
      pull = Offset.fromDirection(pull.direction, limit);
    }
    _pullX
      ..stop()
      ..value = pull.dx;
    _pullY
      ..stop()
      ..value = pull.dy;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_enabled || _trackedPointer != null) return;
    _trackedPointer = event.pointer;
    _lastPointerTime = event.timeStamp;
    _releaseVelocity = Offset.zero;
    _setPull(event.localPosition);
    _animateTo(1);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_trackedPointer != event.pointer) return;
    final previousTime = _lastPointerTime;
    final elapsed = previousTime == null
        ? 0.0
        : (event.timeStamp - previousTime).inMicroseconds /
              Duration.microsecondsPerSecond;
    if (elapsed > 0) {
      _releaseVelocity = Offset(
        event.delta.dx / elapsed,
        event.delta.dy / elapsed,
      );
    }
    _lastPointerTime = event.timeStamp;
    _setPull(event.localPosition);
  }

  void _handlePointerEnd(PointerEvent event) {
    if (_trackedPointer != event.pointer) return;
    _trackedPointer = null;
    _lastPointerTime = null;
    _animateTo(0);
    if (_reduceMotion) {
      _pullX.value = 0;
      _pullY.value = 0;
      return;
    }
    final vx = _releaseVelocity.dx.clamp(-900.0, 900.0);
    final vy = _releaseVelocity.dy.clamp(-900.0, 900.0);
    _pullX.animateWith(SpringSimulation(UiSprings.press, _pullX.value, 0, vx));
    _pullY.animateWith(SpringSimulation(UiSprings.press, _pullY.value, 0, vy));
  }

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
      _pullX.value = 0;
      _pullY.value = 0;
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _pullX.dispose();
    _pullY.dispose();
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
      child: SizedBox.square(
        dimension: widget.size,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerEnd,
          onPointerCancel: _handlePointerEnd,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _enabled ? _handleTap : null,
            onLongPress: _enabled ? widget.onLongPress : null,
            child: AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[_press, _pullX, _pullY]),
              child: child,
              builder: (context, child) {
                final progress = _press.value.clamp(0.0, 1.0);
                final pull = Offset(_pullX.value, _pullY.value);
                final content = Opacity(
                  opacity: _enabled ? 1 : 0.42,
                  child: Transform.translate(
                    offset: pull * (0.035 * progress),
                    child: child,
                  ),
                );
                if (!widget.contained) {
                  return _GlassPressedHighlight(
                    diameter: widget.size,
                    interaction: progress,
                    pull: pull,
                    color: context.uiGlass.pressedFill,
                    child: content,
                  );
                }
                return _InteractiveGlassOrb(
                  diameter: widget.size,
                  variant: widget.variant,
                  tint: widget.tint,
                  enableBlur: widget.enableBlur ?? true,
                  interaction: progress,
                  pull: pull,
                  child: content,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Inside a shared toolbar the outer glass is sampled once. This local sheen is
/// transparent at rest and follows the contact without adding another blur.
class _GlassPressedHighlight extends StatelessWidget {
  const _GlassPressedHighlight({
    required this.diameter,
    required this.interaction,
    required this.pull,
    required this.color,
    required this.child,
  });

  final double diameter;
  final double interaction;
  final Offset pull;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final progress = interaction.clamp(0.0, 1.0);
    final half = diameter / 2;
    final normalized = Offset(
      (pull.dx / half).clamp(-1.0, 1.0),
      (pull.dy / half).clamp(-1.0, 1.0),
    );
    return Transform.translate(
      offset: pull * (0.035 * progress),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          1 - (0.02 * progress),
          1 - (0.045 * progress),
          1,
        ),
        child: CustomPaint(
          painter: _PressedSheenPainter(
            progress: progress,
            position: normalized,
            color: color,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A compact clear-glass control. Its silhouette remains stable; the lens,
/// specular rim and content shift toward the contact, then spring home.
class _InteractiveGlassOrb extends StatelessWidget {
  const _InteractiveGlassOrb({
    required this.diameter,
    required this.variant,
    required this.enableBlur,
    required this.interaction,
    required this.pull,
    required this.child,
    this.tint,
  });

  final double diameter;
  final UiGlassVariant variant;
  final bool enableBlur;
  final double interaction;
  final Offset pull;
  final Color? tint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glass = context.uiGlass;
    final progress = interaction.clamp(0.0, 1.0);
    final visualDiameter = math.max(32.0, diameter - 4);
    final half = diameter / 2;
    final normalized = Offset(
      (pull.dx / half).clamp(-1.0, 1.0),
      (pull.dy / half).clamp(-1.0, 1.0),
    );
    final baseFill = switch (variant) {
      UiGlassVariant.clear => glass.clearFill,
      UiGlassVariant.regular => glass.regularFill,
    };
    var fill = Color.alphaBlend(
      glass.pressedFill.withValues(alpha: glass.pressedFill.a * progress),
      baseFill,
    );
    if (tint case final color?) {
      fill = Color.alphaBlend(color.withValues(alpha: 0.10), fill);
    }
    final border = tint == null
        ? glass.border
        : Color.lerp(glass.border, tint, 0.12)!;
    final blurSigma = switch (variant) {
      UiGlassVariant.clear => glass.clearBlurSigma,
      UiGlassVariant.regular => glass.regularBlurSigma,
    };

    final opticalMaterial = DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(
            -0.45 + (normalized.dx * 0.42),
            -0.62 + (normalized.dy * 0.42),
          ),
          radius: 1.18,
          colors: <Color>[
            Color.alphaBlend(
              glass.highlight.withValues(alpha: 0.17 + 0.08 * progress),
              fill,
            ),
            fill,
            Color.alphaBlend(Colors.black.withValues(alpha: 0.045), fill),
          ],
          stops: const <double>[0, 0.52, 1],
        ),
      ),
      child: CustomPaint(
        foregroundPainter: _OpticalRimPainter(
          border: border,
          highlight: glass.highlight,
          progress: progress,
          position: normalized,
        ),
        child: Center(child: child),
      ),
    );
    Widget material = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (enableBlur)
          Positioned.fill(
            child: _GlassRefractionRim(
              borderRadius: BorderRadius.circular(visualDiameter / 2),
              thickness: 3.2,
              scaleX: 1.045 + normalized.dx.abs() * progress * 0.018,
              scaleY: 1.045 + normalized.dy.abs() * progress * 0.018,
              shift: normalized * (1.35 * progress),
            ),
          ),
        opticalMaterial,
      ],
    );
    if (enableBlur && blurSigma > 0) {
      material = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: material,
      );
    }

    return Center(
      child: Transform.translate(
        key: const ValueKey<String>('ui-glass-orb'),
        offset: pull * (0.055 * progress),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(
            1 - (0.025 * progress) + (0.010 * normalized.dx.abs() * progress),
            1 - (0.040 * progress) + (0.010 * normalized.dy.abs() * progress),
            1,
          ),
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: glass.shadow.withValues(alpha: glass.shadow.a * 0.7),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: ClipOval(
                clipBehavior: Clip.antiAlias,
                child: SizedBox.square(
                  dimension: visualDiameter,
                  child: material,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OpticalRimPainter extends CustomPainter {
  const _OpticalRimPainter({
    required this.border,
    required this.highlight,
    required this.progress,
    required this.position,
  });

  final Color border;
  final Color highlight;
  final double progress;
  final Offset position;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = (Offset.zero & size).deflate(0.65);
    canvas.drawOval(
      bounds,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.55
        ..color = border,
    );

    final hasContact = position.distance > 0.04;
    final direction = hasContact ? position.direction : -math.pi * 0.72;
    canvas.drawArc(
      bounds,
      direction - 0.82,
      1.64,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.05
        ..color = highlight.withValues(alpha: 0.18 + 0.16 * progress),
    );
    canvas.drawArc(
      bounds,
      direction + math.pi - 0.62,
      1.24,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.8
        ..color = Colors.black.withValues(alpha: 0.06 + 0.04 * progress),
    );
  }

  @override
  bool shouldRepaint(covariant _OpticalRimPainter oldDelegate) =>
      border != oldDelegate.border ||
      highlight != oldDelegate.highlight ||
      progress != oldDelegate.progress ||
      position != oldDelegate.position;
}

class _PressedSheenPainter extends CustomPainter {
  const _PressedSheenPainter({
    required this.progress,
    required this.position,
    required this.color,
  });

  final double progress;
  final Offset position;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = size.center(
      Offset(position.dx * size.width * 0.12, position.dy * size.height * 0.12),
    );
    final paint = Paint()
      ..shader =
          RadialGradient(
            colors: <Color>[
              color.withValues(alpha: color.a * progress),
              color.withValues(alpha: color.a * progress * 0.34),
              color.withValues(alpha: 0),
            ],
            stops: const <double>[0, 0.58, 1],
          ).createShader(
            Rect.fromCircle(center: center, radius: diameterFor(size) * 0.54),
          );
    canvas.drawCircle(center, diameterFor(size) * 0.54, paint);
  }

  double diameterFor(Size size) => math.min(size.width, size.height);

  @override
  bool shouldRepaint(covariant _PressedSheenPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      position != oldDelegate.position ||
      color != oldDelegate.color;
}

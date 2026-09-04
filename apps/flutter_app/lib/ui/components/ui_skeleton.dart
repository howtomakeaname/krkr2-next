import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// 骨架屏（Shimmer Placeholder）。
///
/// 使用 [ShaderMask] + [AnimationController] 实现低成本的渐变扫光效果，
/// 相比 `shimmer` 第三方包无需额外依赖、纯 CustomPainter 即可。
///
/// 组合使用：
/// ```dart
/// UiSkeleton(width: 120, height: 16);
/// UiSkeleton.circle(size: 40);
/// ```
class UiSkeleton extends StatefulWidget {
  const UiSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = UiRadius.brSm,
    this.shape = BoxShape.rectangle,
  });

  /// 圆形占位（如头像）。
  const UiSkeleton.circle({super.key, required double size})
    : width = size,
      height = size,
      borderRadius = UiRadius.brPill,
      shape = BoxShape.circle;

  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final BoxShape shape;

  @override
  State<UiSkeleton> createState() => _UiSkeletonState();
}

class _UiSkeletonState extends State<UiSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final base = colors.shimmer;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final highlightTarget = isLight ? colors.surface : colors.textPrimary;
    final highlight =
        Color.lerp(base, highlightTarget, isLight ? 0.72 : 0.18) ?? base;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: const [0.25, 0.5, 0.75],
              transform: _SlidingGradient(_controller.value),
            ).createShader(rect);
          },
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: base,
              shape: widget.shape,
              borderRadius: widget.shape == BoxShape.rectangle
                  ? widget.borderRadius
                  : null,
            ),
          ),
        );
      },
    );
  }
}

class _SlidingGradient extends GradientTransform {
  const _SlidingGradient(this.progress);
  final double progress;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (progress * 2 - 1), 0, 0);
  }
}

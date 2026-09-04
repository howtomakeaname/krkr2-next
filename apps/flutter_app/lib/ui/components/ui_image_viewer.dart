import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// 可缩放 / 可拖拽的图片查看器。
///
/// - 支持双指捏合缩放（1x – [maxScale]），双击智能缩放/还原；
/// - 支持左右滑动切换图片（多图时内部使用 [PageView]）；
/// - 顶部关闭按钮与页码指示器；
/// - 页面背景纯黑，状态栏样式自适应。
///
/// 典型调用：
/// ```dart
/// UiImageViewer.show(
///   context,
///   images: [ NetworkImage('https://...'), ... ],
///   initialIndex: 2,
/// );
/// ```
class UiImageViewer extends StatefulWidget {
  const UiImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.maxScale = 4,
    this.heroTagBuilder,
  });

  final List<ImageProvider> images;
  final int initialIndex;
  final double maxScale;
  final Object Function(int index)? heroTagBuilder;

  /// 弹出全屏图片查看器。
  static Future<void> show(
    BuildContext context, {
    required List<ImageProvider> images,
    int initialIndex = 0,
    double maxScale = 4,
    Object Function(int index)? heroTagBuilder,
  }) {
    final colors = context.uiColors;
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: colors.overlay.withValues(alpha: 1),
        transitionDuration: UiDuration.base,
        reverseTransitionDuration: UiDuration.base,
        pageBuilder: (_, _, _) => UiImageViewer(
          images: images,
          initialIndex: initialIndex,
          maxScale: maxScale,
          heroTagBuilder: heroTagBuilder,
        ),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  State<UiImageViewer> createState() => _UiImageViewerState();
}

class _UiImageViewerState extends State<UiImageViewer> {
  late int _index = widget.initialIndex;
  late final PageController _pc = PageController(
    initialPage: widget.initialIndex,
  );

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colors.overlay.withValues(alpha: 1),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: PageView.builder(
                  controller: _pc,
                  itemCount: widget.images.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) {
                    Widget child = _ZoomableImage(
                      image: widget.images[i],
                      maxScale: widget.maxScale,
                      onDismiss: () => Navigator.of(context).maybePop(),
                    );
                    if (widget.heroTagBuilder != null) {
                      child = Hero(
                        tag: widget.heroTagBuilder!(i),
                        child: child,
                      );
                    }
                    return child;
                  },
                ),
              ),
              // 顶部工具栏
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    _RoundIconButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    if (widget.images.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.textOnBrand.withValues(alpha: 0.2),
                          borderRadius: UiRadius.brPill,
                        ),
                        child: Text(
                          '${_index + 1}/${widget.images.length}',
                          style: TextStyle(
                            color: colors.textOnBrand,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({
    required this.image,
    required this.maxScale,
    required this.onDismiss,
  });

  final ImageProvider image;
  final double maxScale;
  final VoidCallback onDismiss;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  late final TransformationController _tc = TransformationController();
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: UiDuration.base,
  );
  Animation<Matrix4>? _anim;
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _tc.dispose();
    _ac.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final end = _tc.value.isIdentity() ? _zoomedMatrix() : Matrix4.identity();
    _anim =
        Matrix4Tween(begin: _tc.value, end: end).animate(
          CurvedAnimation(parent: _ac, curve: UiCurves.emphasized),
        )..addListener(() {
          _tc.value = _anim!.value;
        });
    _ac
      ..reset()
      ..forward();
  }

  Matrix4 _zoomedMatrix() {
    final pos =
        _doubleTapDetails?.localPosition ??
        Offset(
          MediaQuery.sizeOf(context).width / 2,
          MediaQuery.sizeOf(context).height / 2,
        );
    const scale = 2.5;
    final x = -pos.dx * (scale - 1);
    final y = -pos.dy * (scale - 1);
    return Matrix4.identity()
      ..translateByDouble(x, y, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTapDetails = d,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _tc,
        minScale: 1,
        maxScale: widget.maxScale,
        clipBehavior: Clip.none,
        child: Center(
          child: Image(
            image: widget.image,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(
              Icons.broken_image_outlined,
              color: colors.textOnBrand,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    return Material(
      color: colors.textOnBrand.withValues(alpha: 0.2),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: UiNavigationMetrics.buttonExtent,
          height: UiNavigationMetrics.buttonExtent,
          child: Icon(
            icon,
            color: colors.textOnBrand,
            size: UiNavigationMetrics.iconSize,
          ),
        ),
      ),
    );
  }
}

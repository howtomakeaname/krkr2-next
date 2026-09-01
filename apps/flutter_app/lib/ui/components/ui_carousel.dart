import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// 图集轮播。
///
/// - 基于 [PageView]，支持左右滑动、循环、自动播放；
/// - 默认页码指示器为 iOS 小圆点（当前页略放大+品牌色）；
/// - 可选展示 "1/n" 文本计数器；
/// - 支持无限循环（内部把 index 映射到 children.length 取模）。
class UiCarousel extends StatefulWidget {
  const UiCarousel({
    super.key,
    required this.items,
    this.height = 200,
    this.aspectRatio,
    this.viewportFraction = 1,
    this.loop = true,
    this.autoPlay = false,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.indicator = UiCarouselIndicator.dots,
    this.onChanged,
    this.borderRadius = UiRadius.brLg,
  }) : assert(items.length > 0, 'UiCarousel 至少需要 1 张');

  final List<Widget> items;
  final double height;

  /// 指定宽高比时忽略 [height]。
  final double? aspectRatio;

  /// 视口宽度占比（<1 时会看到相邻卡片边缘，用于画廊效果）。
  final double viewportFraction;

  final bool loop;
  final bool autoPlay;
  final Duration autoPlayInterval;
  final UiCarouselIndicator indicator;
  final ValueChanged<int>? onChanged;

  final BorderRadius borderRadius;

  @override
  State<UiCarousel> createState() => _UiCarouselState();
}

enum UiCarouselIndicator { none, dots, counter }

class _UiCarouselState extends State<UiCarousel> {
  static const int _loopBase = 10000;
  late final PageController _pc = PageController(
    viewportFraction: widget.viewportFraction,
    initialPage: widget.loop ? _loopBase : 0,
  );
  int _realIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restartAutoPlay();
  }

  @override
  void didUpdateWidget(covariant UiCarousel old) {
    super.didUpdateWidget(old);
    if (old.autoPlay != widget.autoPlay ||
        old.autoPlayInterval != widget.autoPlayInterval) {
      _restartAutoPlay();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  void _restartAutoPlay() {
    _timer?.cancel();
    if (!widget.autoPlay || widget.items.length <= 1) return;
    _timer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!_pc.hasClients) return;
      _pc.nextPage(duration: UiDuration.slow, curve: UiCurves.standard);
    });
  }

  int _mapIndex(int raw) {
    if (!widget.loop) return raw;
    return raw % widget.items.length;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;

    final pageView = PageView.builder(
      controller: _pc,
      onPageChanged: (i) {
        final real = _mapIndex(i);
        setState(() => _realIndex = real);
        widget.onChanged?.call(real);
      },
      itemCount: widget.loop ? null : widget.items.length,
      itemBuilder: (context, i) {
        final real = _mapIndex(i);
        final item = widget.items[real];
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.viewportFraction < 1 ? UiSpacing.xs : 0,
          ),
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: item,
          ),
        );
      },
    );

    final content = widget.aspectRatio != null
        ? AspectRatio(aspectRatio: widget.aspectRatio!, child: pageView)
        : SizedBox(height: widget.height, child: pageView);

    return Listener(
      // 手指按下时暂停自动播放，抬起后继续。
      onPointerDown: (_) => _timer?.cancel(),
      onPointerUp: (_) => _restartAutoPlay(),
      onPointerCancel: (_) => _restartAutoPlay(),
      child: Stack(
        children: [
          content,
          if (widget.indicator == UiCarouselIndicator.dots &&
              widget.items.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: _Dots(
                count: widget.items.length,
                current: _realIndex,
                brand: colors.brand,
                background: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          if (widget.indicator == UiCarouselIndicator.counter &&
              widget.items.length > 1)
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: UiRadius.brPill,
                ),
                child: Text(
                  '${_realIndex + 1}/${widget.items.length}',
                  style: typography.caption.copyWith(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({
    required this.count,
    required this.current,
    required this.brand,
    required this.background,
  });

  final int count;
  final int current;
  final Color brand;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: UiDuration.base,
          curve: UiCurves.standard,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? brand : background,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

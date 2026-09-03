import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
import '../theme/ui_typography.dart';

enum _RefreshMode { idle, pulling, ready, refreshing, done }

/// 小红书风格下拉刷新。
///
/// 与系统 Material [RefreshIndicator] 的差异：
/// - 顶部指示器是 **三点水平跳动** + 中文文字状态（下拉刷新 / 释放刷新 /
///   正在刷新 / 刷新成功），视觉更轻盈；
/// - 拉动时整体不弹性回弹，而是**指示器高度随下拉距离线性展开**，与小红书
///   "内容被轻轻推下去" 的体感一致；
/// - 刷新成功后会停留 600ms 显示成功态，再平滑收起。
///
/// 实现要点：
/// - 组件内部用 [NotificationListener] 订阅 [ScrollNotification]；
/// - 通过 [ScrollConfiguration] 注入 [BouncingScrollPhysics]，确保在 Android
///   上也能识别到 `metrics.pixels < 0` 的超限滑动；
/// - 刷新进行时给 child 增加顶部 padding 腾出空间，不会把内容裁掉。
class UiPullRefresh extends StatefulWidget {
  const UiPullRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.indicatorHeight = 64,
    this.triggerDistance = 60,
    this.maxDistance = 120,
    this.successDuration = const Duration(milliseconds: 600),
    this.pullingText = '下拉刷新',
    this.readyText = '释放刷新',
    this.refreshingText = '正在刷新',
    this.doneText = '刷新成功',
    this.accentColor,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  /// 刷新中指示器固定高度。
  final double indicatorHeight;

  /// 松手触发刷新所需的最小下拉距离。
  final double triggerDistance;

  /// 允许的最大下拉距离（超过后视觉上阻尼，不再跟手）。
  final double maxDistance;

  /// 刷新成功后保留 "刷新成功" 状态的时长。
  final Duration successDuration;

  final String pullingText;
  final String readyText;
  final String refreshingText;
  final String doneText;

  final Color? accentColor;

  @override
  State<UiPullRefresh> createState() => _UiPullRefreshState();
}

class _UiPullRefreshState extends State<UiPullRefresh>
    with TickerProviderStateMixin {
  _RefreshMode _mode = _RefreshMode.idle;
  double _drag = 0;
  // 松手后指示器正在自己收回，期间忽略列表回弹带来的滚动通知。
  bool _settling = false;
  // 列表当前自己越界了多少（BouncingScrollPhysics 的回弹位移）。
  // 手指按着时列表已经被物理推下去了，内容只需再补 _drag 超出的部分，
  // 否则会叠成双倍位移，看起来像整页被拽走。
  double _overscroll = 0;

  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  // 当前 _settle 上挂载的缓动监听器引用，用于在动画完成后精确移除，
  // 避免多次 _animateTo 叠加监听导致内存泄漏。
  VoidCallback? _settleListener;

  @override
  void dispose() {
    if (_settleListener != null) {
      _settle.removeListener(_settleListener!);
    }
    _settle.dispose();
    super.dispose();
  }

  double _applyDamping(double raw) {
    if (raw <= widget.triggerDistance) return raw;
    // 超过触发点后阻尼：每多拉一段只呈现一半。
    final extra = raw - widget.triggerDistance;
    final dampened = widget.triggerDistance + extra * 0.45;
    return dampened.clamp(0, widget.maxDistance);
  }

  bool _handleScroll(ScrollNotification n) {
    final pixels = n.metrics.pixels;
    final overscroll = pixels < 0 ? -pixels : 0.0;
    if (overscroll != _overscroll) {
      setState(() => _overscroll = overscroll);
    }
    if (_mode == _RefreshMode.refreshing ||
        _mode == _RefreshMode.done ||
        _settling) {
      return false;
    }

    // 只响应顶部越界滑动。
    if (pixels > 0) {
      if (_drag != 0) {
        setState(() {
          _drag = 0;
          _mode = _RefreshMode.idle;
        });
      }
      return false;
    }

    if (n is ScrollUpdateNotification || n is OverscrollNotification) {
      // BouncingScrollPhysics 下手指一抬列表就自己回弹，回弹期间的更新没有
      // dragDetails。要在这一刻拍板，不能等 ScrollEnd——那时 _drag 早被回弹
      // 更新冲回 0 了（Material RefreshIndicator 也是这么判的）。
      final fingerDown = n is ScrollUpdateNotification
          ? n.dragDetails != null
          : (n as OverscrollNotification).dragDetails != null;
      if (!fingerDown) {
        _onRelease();
        return false;
      }
      final raw = -pixels.clamp(-widget.maxDistance * 4, 0.0).toDouble();
      final damped = _applyDamping(raw);
      setState(() {
        _drag = damped;
        _mode = damped >= widget.triggerDistance
            ? _RefreshMode.ready
            : _RefreshMode.pulling;
      });
    } else if (n is ScrollEndNotification) {
      // Clamping 物理（无回弹）时松手直接到 ScrollEnd，这里兜底。
      _onRelease();
    }
    return false;
  }

  /// 松手：够距离就刷新，不够就把指示器收回去。
  void _onRelease() {
    if (_mode == _RefreshMode.ready) {
      _startRefresh();
    } else if (_drag > 0) {
      _settling = true;
      _animateTo(0).then((_) {
        _settling = false;
        if (mounted) {
          setState(() => _mode = _RefreshMode.idle);
        }
      });
    }
  }

  Future<void> _animateTo(double target) async {
    final from = _drag;
    // 切换目标前，先卸载旧监听器，防止重复 setState。
    if (_settleListener != null) {
      _settle.removeListener(_settleListener!);
      _settleListener = null;
    }
    void listener() {
      if (!mounted) return;
      setState(() {
        _drag = from + (target - from) * _settle.value;
      });
    }

    _settleListener = listener;
    _settle
      ..reset()
      ..addListener(listener);
    try {
      await _settle.forward();
    } finally {
      if (_settleListener == listener) {
        _settle.removeListener(listener);
        _settleListener = null;
      }
    }
  }

  Future<void> _startRefresh() async {
    setState(() {
      _mode = _RefreshMode.refreshing;
    });
    await _animateTo(widget.indicatorHeight);
    try {
      await widget.onRefresh();
    } catch (_) {
      // onRefresh 抛错时继续进入 done（用户可在 onRefresh 内做错误提示）
    }
    if (!mounted) return;
    setState(() => _mode = _RefreshMode.done);
    await Future.delayed(widget.successDuration);
    if (!mounted) return;
    await _animateTo(0);
    if (!mounted) return;
    setState(() => _mode = _RefreshMode.idle);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final accent = widget.accentColor ?? colors.brand;

    final indicatorVisible = _drag > 0 ||
        _mode == _RefreshMode.refreshing ||
        _mode == _RefreshMode.done;

    return ClipRect(
      child: Stack(
        children: [
          // 指示器：位于列表顶部，高度随 _drag 变化。
          if (indicatorVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _drag,
              child: _Indicator(
                mode: _mode,
                progress:
                    (_drag / widget.triggerDistance).clamp(0.0, 1.0).toDouble(),
                accent: accent,
                backgroundColor: colors.background,
                typography: typography,
                textSecondary: colors.textSecondary,
                pullingText: widget.pullingText,
                readyText: widget.readyText,
                refreshingText: widget.refreshingText,
                doneText: widget.doneText,
              ),
            ),
          // 内容区域：刷新进行中向下偏移 indicatorHeight 腾出空间。
          // 手指按着时列表已经被物理回弹推下去 _overscroll，这里只补差额。
          Transform.translate(
            offset: Offset(0, (_drag - _overscroll).clamp(0.0, _drag)),
            child: ScrollConfiguration(
              behavior: const _BouncingScrollBehavior(),
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleScroll,
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 强制允许顶部越界滑动，以便在 Android 上也能用 `metrics.pixels < 0` 检测下拉。
class _BouncingScrollBehavior extends ScrollBehavior {
  const _BouncingScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

/// 小红书风格指示器：三点跳动 + 中文状态文本。
class _Indicator extends StatefulWidget {
  const _Indicator({
    required this.mode,
    required this.progress,
    required this.accent,
    required this.backgroundColor,
    required this.typography,
    required this.textSecondary,
    required this.pullingText,
    required this.readyText,
    required this.refreshingText,
    required this.doneText,
  });

  final _RefreshMode mode;
  final double progress;
  final Color accent;
  final Color backgroundColor;
  final UiTypography typography;
  final Color textSecondary;
  final String pullingText;
  final String readyText;
  final String refreshingText;
  final String doneText;

  @override
  State<_Indicator> createState() => _IndicatorState();
}

class _IndicatorState extends State<_Indicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.mode == _RefreshMode.refreshing) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant _Indicator old) {
    super.didUpdateWidget(old);
    if (widget.mode == _RefreshMode.refreshing && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (widget.mode != _RefreshMode.refreshing && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _text() {
    switch (widget.mode) {
      case _RefreshMode.pulling:
      case _RefreshMode.idle:
        return widget.pullingText;
      case _RefreshMode.ready:
        return widget.readyText;
      case _RefreshMode.refreshing:
        return widget.refreshingText;
      case _RefreshMode.done:
        return widget.doneText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: UiSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Glyph(
            mode: widget.mode,
            progress: widget.progress,
            accent: widget.accent,
            controller: _ctrl,
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: UiDuration.fast,
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
            child: Text(
              _text(),
              key: ValueKey(_text()),
              style: widget.typography.caption.copyWith(
                color: widget.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 指示器图形：
/// - 下拉中：三点按拉动进度依次亮起；
/// - 释放刷新：三点全亮且略放大；
/// - 刷新中：三点循环跳动；
/// - 刷新成功：显示一个对勾。
class _Glyph extends StatelessWidget {
  const _Glyph({
    required this.mode,
    required this.progress,
    required this.accent,
    required this.controller,
  });

  final _RefreshMode mode;
  final double progress;
  final Color accent;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    if (mode == _RefreshMode.done) {
      return Icon(Icons.check_rounded, size: 22, color: accent);
    }

    return SizedBox(
      width: 36,
      height: 18,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(3, (i) {
              final t = controller.value;
              // 三点依次跳动：偏移量按相位差 1/3 周期展开。
              final phase = (t - i * 0.15) % 1.0;
              final bounce = mode == _RefreshMode.refreshing
                  ? _bounceCurve(phase)
                  : 0.0;

              double alpha;
              double scale;
              if (mode == _RefreshMode.ready) {
                alpha = 1;
                scale = 1.1;
              } else if (mode == _RefreshMode.refreshing) {
                alpha = 0.6 + 0.4 * bounce;
                scale = 0.9 + 0.35 * bounce;
              } else {
                // pulling：按进度依次点亮
                final threshold = (i + 1) / 3.5;
                alpha = progress >= threshold ? 1 : 0.25;
                scale = 0.85 + 0.2 * progress;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Transform.translate(
                  offset: Offset(0, -6 * bounce),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: alpha),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  double _bounceCurve(double t) {
    // 单峰：在 0..0.5 区间上升到 1，0.5..1 下降到 0。
    if (t < 0.5) return Curves.easeOut.transform(t * 2);
    return Curves.easeIn.transform((1 - t) * 2);
  }
}

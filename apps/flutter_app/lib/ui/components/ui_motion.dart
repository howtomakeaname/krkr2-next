import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';

/// 统一的 iOS 18 风格动效工具集。
///
/// 设计目标：
/// 1. **一致性**：所有 push / modal / overlay 的曲线 + 时长都走同一份定义；
/// 2. **iOS 原生手感**：
///    - 页面级推拉直接复用 Flutter 内置的 [CupertinoPageTransition]，自带
///      iOS 的边缘返回手势、投影、底层 parallax；
///    - Modal 使用 iOS 15+ 的 Sheet 叠加效果：上层从底部推入，下层轻微
///      缩放 + 圆角下沉；
///    - Dialog / menu 使用 "缩放 + 淡入"，曲线采用 [UiCurves.iosSpringOut]
///      带微弱回弹；
/// 3. **性能**：
///    - [CurvedAnimation] 不在每帧 `buildTransitions` 中分配，而是以
///      StatefulWidget + `didUpdateWidget` 缓存（Flutter 自身 Cupertino
///      模块的做法）；
///    - Tween 以 `static final` 存活整个 App 生命周期，不重复 GC；
///    - 所有过渡组件都是 [FadeTransition] / [SlideTransition] /
///      [ScaleTransition] 等"原生"动画，仅触发重绘而非重建；
///    - [UiHero.flightShuttleBuilder] 仅对外层透明度做插值，内部 widget
///      只在起止两次 build，不会每帧重建。
class UiMotion {
  UiMotion._();

  // ---------- 公共 Tween（避免 buildTransitions 里反复分配） ----------

  static final Tween<Offset> _bottomToCenter =
      Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero);

  static final Tween<double> _underlyingScale =
      Tween<double>(begin: 1, end: 0.92);

  static final Tween<double> _underlyingCornerRadius =
      Tween<double>(begin: 0, end: 14);

  static final Tween<double> _scaleIn =
      Tween<double>(begin: 0.94, end: 1);

  // ---------- 作为 buildTransitions 返回值的 Widget helpers ----------

  /// 页面过渡：iOS 导航推拉（右入左出 + 底层 parallax + 底层压暗）。
  static Widget page(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // CupertinoPageTransition 内部已做了 CurvedAnimation 缓存 & parallax，
    // 这里直接复用是性能最好的选择；压暗层见 [UiParallaxDim]。
    return CupertinoPageTransition(
      primaryRouteAnimation: animation,
      secondaryRouteAnimation: secondaryAnimation,
      linearTransition: false,
      child: UiParallaxDim(secondary: secondaryAnimation, child: child),
    );
  }

  /// Modal 过渡：iOS 15+ Sheet 叠加风格。
  static Widget modal(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _SheetTransition(
      primary: animation,
      secondary: secondaryAnimation,
      child: child,
    );
  }

  /// 弹层过渡：淡入 + 缩放，带轻微 spring 回弹。
  ///
  /// 适合 Dialog、Toast、长按菜单等"从中心弹出"的轻量弹层。
  static Widget fadeScale(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _FadeScaleTransition(animation: animation, child: child);
  }

  // ---------- 便捷入口 ----------

  /// 快捷 push。
  ///
  /// - `style == page`：走 [MaterialPageRoute]，由主题里的
  ///   [UiIosPageTransitionsBuilder] 统一渲染（与业务页直接 `Navigator.push`
  ///   的 MaterialPageRoute 完全同一条路径，自动获得 iOS 边缘返回手势）；
  /// - 其它 style：使用自定义 [UiPageRoute]。
  static Future<T?> push<T>(
    BuildContext context,
    Widget page, {
    UiMotionStyle style = UiMotionStyle.page,
    bool rootNavigator = false,
    bool fullscreenDialog = false,
    RouteSettings? settings,
  }) {
    final navigator = Navigator.of(context, rootNavigator: rootNavigator);
    if (style == UiMotionStyle.page) {
      return navigator.push<T>(
        MaterialPageRoute<T>(
          builder: (_) => page,
          fullscreenDialog: fullscreenDialog,
          settings: settings,
        ),
      );
    }
    return navigator.push<T>(
      UiPageRoute<T>(
        builder: (_) => page,
        style: style,
        fullscreenDialog: fullscreenDialog,
        settings: settings,
      ),
    );
  }
}

/// 可选的页面过渡风格。
enum UiMotionStyle { page, modal, fadeScale }

// ----------------------------------------------------------------------
// 主题级页面过渡：iOS 18 导航推拉
// ----------------------------------------------------------------------

/// 供 `ThemeData.pageTransitionsTheme` 使用的 iOS 18 风格导航过渡。
///
/// 所有业务页直接 `Navigator.push(MaterialPageRoute(...))` 即可获得：
/// - 新页从右侧整幅滑入（`Curves.fastEaseInToSlowEaseOut`，Flutter 团队按
///   真机 UIKit 推拉标定的曲线），前缘带 iOS 的柔和投影；
/// - 旧页向左退 1/3 宽度（UIKit parallax），并逐渐压暗 ~10%
///   （UIKit `_UIParallaxDimmingView` 的观感）；
/// - 屏幕左缘拖拽返回，拖拽期间为线性跟手，松手后按速度决定回弹/完成；
/// - 时长沿用 UIKit 推拉 0.5s。
///
/// 相比直接用 [CupertinoPageTransitionsBuilder]：
/// 1. 显式覆盖 [TargetPlatform] 全部枚举值（含 OHOS fork 新增的
///    `TargetPlatform.ohos`）——否则 OHOS 端会掉进 Material 的
///    Zoom/OpenRightwards 过渡，观感与 iOS 完全不同；
/// 2. 补上 UIKit 的底层压暗；
/// 3. 压暗层用 `drawRect` 直接混色而非 `Opacity`/`FadeTransition`，全程不引入
///    saveLayer；底层页由 ModalScope 自带的 RepaintBoundary 缓存，过渡期间只做
///    合成（translate）而不重绘内容。
class UiIosPageTransitionsBuilder extends PageTransitionsBuilder {
  const UiIosPageTransitionsBuilder();

  @override
  Duration get transitionDuration =>
      CupertinoRouteTransitionMixin.kTransitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      CupertinoRouteTransitionMixin.kTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      CupertinoPageTransition.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 复用 Cupertino 的整套推拉 + 边缘返回手势（含 popGestureInProgress 时的
    // 线性跟手），只在页面内容外多包一层压暗。
    return CupertinoRouteTransitionMixin.buildPageTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      UiParallaxDim(
        secondary: secondaryAnimation,
        linearTransition: route.popGestureInProgress,
        child: child,
      ),
    );
  }

  /// 给 `PageTransitionsTheme(builders: ...)` 用的完整平台映射。
  ///
  /// 用 `TargetPlatform.values` 动态展开，而不是逐个硬编码：这样在上游 Flutter
  /// 与 OHOS fork（多出 `TargetPlatform.ohos`）上都能编译并全部覆盖。
  static Map<TargetPlatform, PageTransitionsBuilder> get builders =>
      <TargetPlatform, PageTransitionsBuilder>{
        for (final TargetPlatform p in TargetPlatform.values)
          p: const UiIosPageTransitionsBuilder(),
      };
}

/// iOS 推拉时底层页面的压暗层。
///
/// 由 `secondaryAnimation`（本页被新页压住时 0→1）驱动，曲线与
/// [CupertinoPageTransition] 的 parallax 位移保持一致，因此压暗与后退位移
/// 完全同步。
///
/// 性能要点：
/// - [CurvedAnimation] 在 State 中缓存，不在 build 内分配；
/// - `secondary == 0`（没有上层路由 / 已完全 pop）时短路，直接返回 child，
///   不多挂一个 Stack；
/// - 压暗用带 alpha 的 [ColoredBox] 单次 `drawRect` 混色，不用
///   `Opacity`，避免整页 saveLayer；
/// - child 就是 ModalScope 的 RepaintBoundary，过渡期只做 layer 合成。
class UiParallaxDim extends StatefulWidget {
  const UiParallaxDim({
    super.key,
    required this.secondary,
    required this.child,
    this.linearTransition = false,
    this.maxOpacity = 0.10,
  });

  final Animation<double> secondary;
  final Widget child;
  final bool linearTransition;
  final double maxOpacity;

  @override
  State<UiParallaxDim> createState() => _UiParallaxDimState();
}

class _UiParallaxDimState extends State<UiParallaxDim> {
  CurvedAnimation? _curved;

  Animation<double> get _driver => _curved ?? widget.secondary;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(covariant UiParallaxDim old) {
    super.didUpdateWidget(old);
    if (widget.secondary != old.secondary ||
        widget.linearTransition != old.linearTransition) {
      _curved?.dispose();
      _curved = null;
      _setup();
    }
  }

  void _setup() {
    if (widget.linearTransition) return;
    _curved = CurvedAnimation(
      parent: widget.secondary,
      // 与 CupertinoPageTransition 的 _secondaryPositionCurve 一致。
      curve: Curves.linearToEaseOut,
      reverseCurve: Curves.easeInToLinear,
    );
  }

  @override
  void dispose() {
    _curved?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 树形状恒定（始终是 Stack + 压暗层），避免动画起止时切换父节点导致
    // 页面子树被 GlobalKey 重挂、触发整页 relayout。alpha 为 0 时
    // ColoredBox 只是一次透明 drawRect，代价可忽略。
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _driver,
              builder: (context, _) {
                final int alpha = (widget.maxOpacity * _driver.value * 255)
                    .round()
                    .clamp(0, 255);
                return ColoredBox(color: Color.fromARGB(alpha, 0, 0, 0));
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// 统一曲线 / 时长的 [PageRoute]。
///
/// 业务侧通常用 [UiMotion.push] 即可；暴露此类是为了在
/// `MaterialApp.onGenerateRoute` 中按需使用（例如 modal 类型的路由）。
class UiPageRoute<T> extends PageRoute<T> {
  UiPageRoute({
    required this.builder,
    this.style = UiMotionStyle.page,
    this.maintainState = true,
    super.fullscreenDialog,
    super.settings,
    Duration? duration,
    Duration? reverseDuration,
  })  : _duration = duration ?? _defaultDuration(style),
        _reverseDuration = reverseDuration ?? _defaultReverseDuration(style);

  final WidgetBuilder builder;
  final UiMotionStyle style;
  final Duration _duration;
  final Duration _reverseDuration;

  static Duration _defaultDuration(UiMotionStyle s) {
    switch (s) {
      case UiMotionStyle.page:
        return UiDuration.page;
      case UiMotionStyle.modal:
        return UiDuration.slow;
      case UiMotionStyle.fadeScale:
        return UiDuration.base;
    }
  }

  static Duration _defaultReverseDuration(UiMotionStyle s) {
    switch (s) {
      case UiMotionStyle.page:
        return UiDuration.slow;
      case UiMotionStyle.modal:
        return UiDuration.base;
      case UiMotionStyle.fadeScale:
        return UiDuration.fast;
    }
  }

  @override
  final bool maintainState;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => _duration;

  @override
  Duration get reverseTransitionDuration => _reverseDuration;

  @override
  bool get opaque => style == UiMotionStyle.page;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Builder(builder: builder);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    switch (style) {
      case UiMotionStyle.page:
        return UiMotion.page(animation, secondaryAnimation, child);
      case UiMotionStyle.modal:
        return UiMotion.modal(animation, secondaryAnimation, child);
      case UiMotionStyle.fadeScale:
        return UiMotion.fadeScale(animation, secondaryAnimation, child);
    }
  }
}

// ----------------------------------------------------------------------
// 内部：Sheet 过渡（iOS 15+ presentation style）
// ----------------------------------------------------------------------

class _SheetTransition extends StatefulWidget {
  const _SheetTransition({
    required this.primary,
    required this.secondary,
    required this.child,
  });

  final Animation<double> primary;
  final Animation<double> secondary;
  final Widget child;

  @override
  State<_SheetTransition> createState() => _SheetTransitionState();
}

class _SheetTransitionState extends State<_SheetTransition> {
  late CurvedAnimation _primaryCurved;
  late CurvedAnimation _secondaryCurved;

  @override
  void initState() {
    super.initState();
    _primaryCurved = _newPrimary();
    _secondaryCurved = _newSecondary();
  }

  @override
  void didUpdateWidget(covariant _SheetTransition old) {
    super.didUpdateWidget(old);
    if (widget.primary != old.primary) {
      _primaryCurved.dispose();
      _primaryCurved = _newPrimary();
    }
    if (widget.secondary != old.secondary) {
      _secondaryCurved.dispose();
      _secondaryCurved = _newSecondary();
    }
  }

  CurvedAnimation _newPrimary() => CurvedAnimation(
        parent: widget.primary,
        curve: UiCurves.iosStandard,
        reverseCurve: UiCurves.iosSmooth,
      );

  CurvedAnimation _newSecondary() => CurvedAnimation(
        parent: widget.secondary,
        curve: UiCurves.iosSmooth,
      );

  @override
  void dispose() {
    _primaryCurved.dispose();
    _secondaryCurved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 整个 Sheet 子树独占一层 RepaintBoundary：
    // - push/pop 只会触发该层的合成（translate），不会反向 dirty 父级；
    // - 新路由叠压时，secondary 驱动 scale/clip 变化也只影响本层栅格；
    // - 120Hz 设备上能把 Sheet 主体缓存到 GPU layer，避免每帧重新绘制
    //   里面的 BoxShadow / 圆角 / 文字等昂贵内容。
    final Widget slide = RepaintBoundary(
      child: SlideTransition(
        position: UiMotion._bottomToCenter.animate(_primaryCurved),
        child: widget.child,
      ),
    );

    return AnimatedBuilder(
      animation: _secondaryCurved,
      // child 参数把 slide 固定传给 builder，slide 本身不会因 builder
      // 每帧调用而重建。
      child: slide,
      builder: (context, child) {
        final double v = _secondaryCurved.value;
        // 短路：当没有上层路由压在本页时，secondary 恒为 0，不做任何
        // Transform / ClipRRect，彻底避免无谓的 saveLayer。
        if (v == 0.0) return child!;
        final double radius = UiMotion._underlyingCornerRadius.transform(v);
        final double scale = UiMotion._underlyingScale.transform(v);
        return Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: child,
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------------------------
// 内部：FadeScale 过渡（Dialog / 弹层用）
// ----------------------------------------------------------------------

class _FadeScaleTransition extends StatefulWidget {
  const _FadeScaleTransition({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  State<_FadeScaleTransition> createState() => _FadeScaleTransitionState();
}

class _FadeScaleTransitionState extends State<_FadeScaleTransition> {
  late CurvedAnimation _curved;

  @override
  void initState() {
    super.initState();
    _curved = _newCurved();
  }

  @override
  void didUpdateWidget(covariant _FadeScaleTransition old) {
    super.didUpdateWidget(old);
    if (widget.animation != old.animation) {
      _curved.dispose();
      _curved = _newCurved();
    }
  }

  CurvedAnimation _newCurved() => CurvedAnimation(
        parent: widget.animation,
        curve: UiCurves.iosSpringOut,
        reverseCurve: UiCurves.iosSmooth,
      );

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: ScaleTransition(
        scale: UiMotion._scaleIn.animate(_curved),
        child: widget.child,
      ),
    );
  }
}

// ----------------------------------------------------------------------
// Hero 封装
// ----------------------------------------------------------------------

/// Hero 过渡封装。
///
/// - 默认 [createRectTween] 采用 [MaterialRectCenterArcTween]，形成 iOS 的
///   柔性飞行轨迹；
/// - [crossFade] 默认 **false**：iOS 18 的 matchedGeometryEffect 通常只展示
///   单一视图，且双层 Opacity 叠加会导致每帧 2 次 saveLayer，在 120Hz 下
///   开销显著；当起止两端视觉差异较大时可显式置 true 做交叉淡入。
class UiHero extends StatelessWidget {
  const UiHero({
    super.key,
    required this.tag,
    required this.child,
    this.transitionOnUserGestures = true,
    this.crossFade = false,
  });

  final Object tag;
  final Widget child;
  final bool transitionOnUserGestures;
  final bool crossFade;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      transitionOnUserGestures: transitionOnUserGestures,
      createRectTween: (begin, end) =>
          MaterialRectCenterArcTween(begin: begin, end: end),
      flightShuttleBuilder:
          crossFade ? _crossFadeShuttle : null,
      child: child,
    );
  }

  // shuttle 在 Flutter Overlay 上独立构建，这里用 AnimatedBuilder 只重绘
  // 两层 Opacity，不会重建 fromHero / toHero 子树。
  static Widget _crossFadeShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromContext,
    BuildContext toContext,
  ) {
    final Widget fromHero = (fromContext.widget as Hero).child;
    final Widget toHero = (toContext.widget as Hero).child;
    final bool forward = direction == HeroFlightDirection.push;
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final double t = forward ? animation.value : 1 - animation.value;
        return Stack(
          fit: StackFit.passthrough,
          children: [
            Opacity(opacity: 1 - t, child: fromHero),
            Opacity(opacity: t, child: toHero),
          ],
        );
      },
    );
  }
}

// ----------------------------------------------------------------------
// 常驻布局中的过渡组件（供业务/showcase 自由组合）
// ----------------------------------------------------------------------

/// 淡入 + 上移：iOS 风的 "appear" 效果，适合首次挂载的卡片 / section。
class UiFadeSlide extends StatefulWidget {
  const UiFadeSlide({
    super.key,
    required this.animation,
    required this.child,
    this.beginOffset = const Offset(0, 0.04),
  });

  final Animation<double> animation;
  final Widget child;
  final Offset beginOffset;

  @override
  State<UiFadeSlide> createState() => _UiFadeSlideState();
}

class _UiFadeSlideState extends State<UiFadeSlide> {
  late CurvedAnimation _curved;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(covariant UiFadeSlide old) {
    super.didUpdateWidget(old);
    if (widget.animation != old.animation ||
        widget.beginOffset != old.beginOffset) {
      _curved.dispose();
      _attach();
    }
  }

  void _attach() {
    _curved = CurvedAnimation(
      parent: widget.animation,
      curve: UiCurves.iosSmooth,
      reverseCurve: UiCurves.iosStandard,
    );
    _slide =
        Tween<Offset>(begin: widget.beginOffset, end: Offset.zero).animate(_curved);
  }

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// 淡入 + 放大：带 iOS spring 轻微回弹，适合对话框 / 弹出菜单。
class UiScaleFade extends StatefulWidget {
  const UiScaleFade({
    super.key,
    required this.animation,
    required this.child,
    this.beginScale = 0.94,
  });

  final Animation<double> animation;
  final Widget child;
  final double beginScale;

  @override
  State<UiScaleFade> createState() => _UiScaleFadeState();
}

class _UiScaleFadeState extends State<UiScaleFade> {
  late CurvedAnimation _curved;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(covariant UiScaleFade old) {
    super.didUpdateWidget(old);
    if (widget.animation != old.animation ||
        widget.beginScale != old.beginScale) {
      _curved.dispose();
      _attach();
    }
  }

  void _attach() {
    _curved = CurvedAnimation(
      parent: widget.animation,
      curve: UiCurves.iosSpringOut,
      reverseCurve: UiCurves.iosSmooth,
    );
    _scale =
        Tween<double>(begin: widget.beginScale, end: 1).animate(_curved);
  }

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

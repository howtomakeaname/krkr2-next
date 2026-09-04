import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// 需要保留速度与回弹感的交互使用真实弹簧，不用三次贝塞尔近似。
class UiSprings {
  UiSprings._();

  /// 手指按下/松开：响应快、回弹很轻，不抢内容注意力。
  static final SpringDescription press =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 220),
        bounce: 0.12,
      );

  /// 小型玻璃控件的出现和形变。
  static final SpringDescription materialize =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 380),
        bounce: 0.16,
      );

  /// 小型浮层关闭：更短，接近临界阻尼，不让退场拖沓。
  static final SpringDescription dismiss =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 220),
        bounce: 0.02,
      );

  static final Curve materializeCurve = UiSpringCurve(
    materialize,
    const Duration(milliseconds: 380),
  );

  static final Curve dismissCurve = UiSpringCurve(
    dismiss,
    const Duration(milliseconds: 220),
  );
}

/// 把同一份物理弹簧用于由路由提供 0→1 时间轴的过渡。
class UiSpringCurve extends Curve {
  UiSpringCurve(SpringDescription spring, this.duration)
    : _simulation = SpringSimulation(spring, 0, 1, 0);

  final Duration duration;
  final SpringSimulation _simulation;

  @override
  double transformInternal(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return _simulation.x(
      t * duration.inMicroseconds / Duration.microsecondsPerSecond,
    );
  }
}

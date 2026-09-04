import 'package:flutter/material.dart';

/// 统一间距、圆角、尺寸等度量。
///
/// 与 iOS18 视觉对齐：大量使用 16 / 20 / 28 圆角与 12 / 16 / 24 间距。
class UiSpacing {
  UiSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
}

/// 页面级标题栏的统一按钮度量。
class UiNavigationMetrics {
  UiNavigationMetrics._();

  /// 对齐 iOS 导航栏的最小有效点击区域。
  static const double buttonExtent = 44;

  /// 以设置页标题栏图标的视觉尺寸为基准。
  static const double iconSize = 22;
}

class UiRadius {
  UiRadius._();

  static const Radius xs = Radius.circular(6);
  static const Radius sm = Radius.circular(10);
  static const Radius md = Radius.circular(14);
  static const Radius lg = Radius.circular(18);
  static const Radius xl = Radius.circular(22);
  static const Radius xxl = Radius.circular(28);
  static const Radius pill = Radius.circular(999);

  static const BorderRadius brSm = BorderRadius.all(sm);
  static const BorderRadius brMd = BorderRadius.all(md);
  static const BorderRadius brLg = BorderRadius.all(lg);
  static const BorderRadius brXl = BorderRadius.all(xl);
  static const BorderRadius brXxl = BorderRadius.all(xxl);
  static const BorderRadius brPill = BorderRadius.all(pill);
}

/// 全局动效时长节奏，对齐 iOS 18 的交互手感：
///
/// - 微交互（状态 / 文字切换）用 [fast]；
/// - 一般组件内动效（Tab、Switch、Accordion）用 [base]；
/// - 显著动效（BottomSheet、Dialog）用 [slow]；
/// - 页面级（push / pop）用 [page]，与 iOS Navigation 推拉节奏一致。
class UiDuration {
  UiDuration._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 320);
  static const Duration page = Duration(milliseconds: 380);
}

/// iOS 18 风格曲线。
///
/// iOS 原生大量使用临界阻尼弹簧；在 Flutter 中完全用 SpringSimulation 会带来
/// 额外的 per-frame 计算开销，因此这里用最接近的三次 Bezier 做闭式近似，
/// 性能与内置 [Curves] 同级，但视觉与 SwiftUI `.smooth` / `.snappy` 接近。
class UiCurves {
  UiCurves._();

  /// UIKit 默认 "ease" 曲线，适合兜底使用。
  static const Curve ios = Cubic(0.25, 0.1, 0.25, 1);

  /// iOS 导航推拉的节奏（Apple HIG "Emphasized easing"）。
  static const Curve iosStandard = Cubic(0.32, 0.72, 0, 1);

  /// 快速收尾，接近 SwiftUI `.snappy`：按钮按压回弹、Tab 指示器。
  static const Curve iosSnappy = Cubic(0.2, 1, 0.3, 1);

  /// 平滑进出，接近 SwiftUI `.smooth`：展开/收起、跨 section 切换。
  static const Curve iosSmooth = Cubic(0.4, 0, 0.2, 1);

  /// 带轻微回弹的出场（back-out）：Toast、长按菜单出现。
  static const Curve iosSpringOut = Cubic(0.34, 1.3, 0.64, 1);

  // --- 兼容别名（保留旧组件调用不破坏） ---
  /// @deprecated 使用 [iosSmooth] 替代。
  static const Curve standard = iosSmooth;

  /// @deprecated 使用 [iosStandard] 替代。
  static const Curve emphasized = iosStandard;
}

/// 响应式断点：参考 Apple HIG 的 size class。
class UiBreakpoints {
  UiBreakpoints._();

  static const double compact = 600; // phone
  static const double regular = 900; // tablet portrait
  static const double large = 1200; // tablet landscape / desktop
}

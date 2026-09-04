import 'package:flutter/material.dart';

/// Liquid Glass 的材质 token。
///
/// 玻璃是浮在内容之上的功能层，不是内容卡片的替代品。组件只从这里读取
/// 色彩与模糊参数，避免每个页面各自拼一套透明度和阴影。
@immutable
class UiGlassTheme extends ThemeExtension<UiGlassTheme> {
  const UiGlassTheme({
    required this.clearFill,
    required this.regularFill,
    required this.pressedFill,
    required this.border,
    required this.highlight,
    required this.shadow,
    required this.clearBlurSigma,
    required this.regularBlurSigma,
  });

  /// 小型、临时控件使用的轻玻璃。
  final Color clearFill;

  /// 工具栏、菜单和 Sheet 使用的常规玻璃。
  final Color regularFill;

  /// 交互时叠加的亮度，用于让玻璃在触摸下“充能”。
  final Color pressedFill;

  final Color border;
  final Color highlight;
  final Color shadow;
  final double clearBlurSigma;
  final double regularBlurSigma;

  static const UiGlassTheme light = UiGlassTheme(
    clearFill: Color(0x52FFFFFF),
    regularFill: Color(0xA3FFFFFF),
    pressedFill: Color(0x70FFFFFF),
    border: Color(0x9EFFFFFF),
    highlight: Color(0xD6FFFFFF),
    shadow: Color(0x2B000000),
    clearBlurSigma: 16,
    regularBlurSigma: 24,
  );

  static const UiGlassTheme dark = UiGlassTheme(
    clearFill: Color(0x661C1C1E),
    regularFill: Color(0xB01C1C1E),
    pressedFill: Color(0x3DFFFFFF),
    border: Color(0x42FFFFFF),
    highlight: Color(0x66FFFFFF),
    shadow: Color(0x73000000),
    clearBlurSigma: 18,
    regularBlurSigma: 28,
  );

  @override
  UiGlassTheme copyWith({
    Color? clearFill,
    Color? regularFill,
    Color? pressedFill,
    Color? border,
    Color? highlight,
    Color? shadow,
    double? clearBlurSigma,
    double? regularBlurSigma,
  }) {
    return UiGlassTheme(
      clearFill: clearFill ?? this.clearFill,
      regularFill: regularFill ?? this.regularFill,
      pressedFill: pressedFill ?? this.pressedFill,
      border: border ?? this.border,
      highlight: highlight ?? this.highlight,
      shadow: shadow ?? this.shadow,
      clearBlurSigma: clearBlurSigma ?? this.clearBlurSigma,
      regularBlurSigma: regularBlurSigma ?? this.regularBlurSigma,
    );
  }

  @override
  UiGlassTheme lerp(ThemeExtension<UiGlassTheme>? other, double t) {
    if (other is! UiGlassTheme) return this;
    return UiGlassTheme(
      clearFill: Color.lerp(clearFill, other.clearFill, t)!,
      regularFill: Color.lerp(regularFill, other.regularFill, t)!,
      pressedFill: Color.lerp(pressedFill, other.pressedFill, t)!,
      border: Color.lerp(border, other.border, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      clearBlurSigma: _lerpDouble(clearBlurSigma, other.clearBlurSigma, t),
      regularBlurSigma: _lerpDouble(
        regularBlurSigma,
        other.regularBlurSigma,
        t,
      ),
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

extension UiGlassThemeAccess on BuildContext {
  UiGlassTheme get uiGlass =>
      Theme.of(this).extension<UiGlassTheme>() ??
      (Theme.of(this).brightness == Brightness.light
          ? UiGlassTheme.light
          : UiGlassTheme.dark);
}

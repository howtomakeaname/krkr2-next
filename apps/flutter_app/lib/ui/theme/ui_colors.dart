import 'package:flutter/material.dart';

/// iOS18 风格蓝白色调的调色板。
///
/// 提供亮色与暗色两套语义化颜色；所有组件通过 [UiColors] 消费，以便
/// 业务层可以通过自定义 seed 生成蓝/青/紫等主题变体。
@immutable
class UiColors extends ThemeExtension<UiColors> {
  const UiColors({
    required this.brand,
    required this.brandSoft,
    required this.brandMuted,
    required this.background,
    required this.groupedBackground,
    required this.surface,
    required this.surfaceElevated,
    required this.surfacePressed,
    required this.separator,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnBrand,
    required this.success,
    required this.warning,
    required this.danger,
    required this.overlay,
    required this.shimmer,
  });

  /// 主品牌色。
  final Color brand;

  /// 低饱和度品牌色（次要按钮背景等）。
  final Color brandSoft;

  /// 极淡品牌色（悬浮/选中态）。
  final Color brandMuted;

  final Color background;
  final Color groupedBackground;
  final Color surface;
  final Color surfaceElevated;
  final Color surfacePressed;
  final Color separator;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnBrand;
  final Color success;
  final Color warning;
  final Color danger;
  final Color overlay;
  final Color shimmer;

  /// 默认亮色调色板（蓝色 seed）。
  static UiColors get light => fromSeed(const Color(0xFF007AFF), Brightness.light);

  /// 默认暗色调色板（蓝色 seed）。
  static UiColors get dark => fromSeed(const Color(0xFF007AFF), Brightness.dark);

  /// 基于单一 seed 颜色生成完整语义化调色板。
  ///
  /// 品牌色族（brand / brandSoft / brandMuted / textOnBrand）来自 [seed] 并
  /// 在 HSL 空间中调整亮度与饱和度；灰阶、功能色（success/warning/danger）
  /// 保持与 iOS 系统色一致，确保不同品牌色下视觉仍协调。
  static UiColors fromSeed(Color seed, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final hsl = HSLColor.fromColor(seed);

    // 在亮色模式下，brand 适当降低亮度保证对比；
    // 暗色模式下稍微提亮并降饱和度避免刺眼。
    final brand = isLight
        ? hsl
            .withLightness(_clamp(hsl.lightness, 0.42, 0.56))
            .withSaturation(_clamp(hsl.saturation, 0.7, 1.0))
            .toColor()
        : hsl
            .withLightness(_clamp(hsl.lightness + 0.08, 0.55, 0.72))
            .withSaturation(_clamp(hsl.saturation - 0.1, 0.55, 0.95))
            .toColor();

    final brandSoft = isLight
        ? hsl
            .withLightness(0.94)
            .withSaturation(_clamp(hsl.saturation, 0.55, 0.9))
            .toColor()
        : hsl
            .withLightness(0.18)
            .withSaturation(_clamp(hsl.saturation - 0.2, 0.35, 0.7))
            .toColor();

    final brandMuted = isLight
        ? hsl
            .withLightness(0.97)
            .withSaturation(_clamp(hsl.saturation - 0.1, 0.4, 0.8))
            .toColor()
        : hsl
            .withLightness(0.12)
            .withSaturation(_clamp(hsl.saturation - 0.3, 0.25, 0.6))
            .toColor();

    const textOnBrand = Color(0xFFFFFFFF);

    if (isLight) {
      return UiColors(
        brand: brand,
        brandSoft: brandSoft,
        brandMuted: brandMuted,
        background: const Color(0xFFFFFFFF),
        groupedBackground: const Color(0xFFF2F3F7),
        surface: const Color(0xFFFFFFFF),
        surfaceElevated: const Color(0xFFFFFFFF),
        surfacePressed: const Color(0xFFEDEEF2),
        separator: const Color(0x1A3C3C43),
        border: const Color(0x33C6C6C8),
        textPrimary: const Color(0xFF0A0A0F),
        textSecondary: const Color(0xFF636672),
        textTertiary: const Color(0xFF9A9CA6),
        textOnBrand: textOnBrand,
        success: const Color(0xFF30B46C),
        warning: const Color(0xFFFFB020),
        danger: const Color(0xFFFF3B30),
        overlay: const Color(0x66000000),
        shimmer: const Color(0xFFE9EBF0),
      );
    }

    return UiColors(
      brand: brand,
      brandSoft: brandSoft,
      brandMuted: brandMuted,
      background: const Color(0xFF000000),
      groupedBackground: const Color(0xFF0C0C0F),
      surface: const Color(0xFF1C1C1F),
      surfaceElevated: const Color(0xFF26272B),
      surfacePressed: const Color(0xFF2E2F34),
      separator: const Color(0x33FFFFFF),
      border: const Color(0x33FFFFFF),
      textPrimary: const Color(0xFFF2F3F7),
      textSecondary: const Color(0xFFA9ACB6),
      textTertiary: const Color(0xFF6E7180),
      textOnBrand: textOnBrand,
      success: const Color(0xFF34C77A),
      warning: const Color(0xFFFFCD4A),
      danger: const Color(0xFFFF6961),
      overlay: const Color(0x99000000),
      shimmer: const Color(0xFF2A2B30),
    );
  }

  static double _clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  @override
  UiColors copyWith({
    Color? brand,
    Color? brandSoft,
    Color? brandMuted,
    Color? background,
    Color? groupedBackground,
    Color? surface,
    Color? surfaceElevated,
    Color? surfacePressed,
    Color? separator,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textOnBrand,
    Color? success,
    Color? warning,
    Color? danger,
    Color? overlay,
    Color? shimmer,
  }) {
    return UiColors(
      brand: brand ?? this.brand,
      brandSoft: brandSoft ?? this.brandSoft,
      brandMuted: brandMuted ?? this.brandMuted,
      background: background ?? this.background,
      groupedBackground: groupedBackground ?? this.groupedBackground,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfacePressed: surfacePressed ?? this.surfacePressed,
      separator: separator ?? this.separator,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textOnBrand: textOnBrand ?? this.textOnBrand,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      overlay: overlay ?? this.overlay,
      shimmer: shimmer ?? this.shimmer,
    );
  }

  @override
  UiColors lerp(ThemeExtension<UiColors>? other, double t) {
    if (other is! UiColors) return this;
    return UiColors(
      brand: Color.lerp(brand, other.brand, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      brandMuted: Color.lerp(brandMuted, other.brandMuted, t)!,
      background: Color.lerp(background, other.background, t)!,
      groupedBackground:
          Color.lerp(groupedBackground, other.groupedBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfacePressed: Color.lerp(surfacePressed, other.surfacePressed, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textOnBrand: Color.lerp(textOnBrand, other.textOnBrand, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      shimmer: Color.lerp(shimmer, other.shimmer, t)!,
    );
  }
}

/// 预置几种常见 seed，方便业务直接调用。
class UiSeedPalette {
  UiSeedPalette._();

  static const Color teal = Color(0xFF0D8FA0);
  static const Color blue = Color(0xFF007AFF); // iOS system blue
  static const Color cyan = Color(0xFF32ADE6); // iOS system teal
  static const Color mint = Color(0xFF00C7BE); // iOS system mint
  static const Color purple = Color(0xFFAF52DE); // iOS system purple
  static const Color indigo = Color(0xFF5E5CE6); // iOS system indigo
  static const Color pink = Color(0xFFFF2D55); // iOS system pink
  static const Color orange = Color(0xFFFF9500); // iOS system orange
  static const Color green = Color(0xFF34C759); // iOS system green
}

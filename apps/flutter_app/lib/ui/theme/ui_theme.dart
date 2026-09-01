import 'package:flutter/material.dart';

import 'ui_colors.dart';
import 'ui_typography.dart';

/// 全局主题工厂。负责将 [UiColors] / [UiTypography] 等扩展注入到
/// [ThemeData.extensions] 中供组件消费。
///
/// 业务层可通过 [UiTheme.light]/[UiTheme.dark] 传入自定义 [seed] 颜色
/// 生成蓝、青、紫、粉等风格变体，也可直接传入完整的 [palette] 覆盖。
class UiTheme {
  UiTheme._();

  /// 构建亮色主题。
  ///
  /// - [seed]：一键变色的种子颜色，品牌色族（brand/brandSoft/brandMuted）
  ///   会基于它在 HSL 空间生成；默认 iOS 系统蓝。
  /// - [palette]：若已有完整 [UiColors] 可直接传入，会跳过 seed 生成。
  /// - [typography]：自定义排版。
  static ThemeData light({
    Color seed = UiSeedPalette.teal,
    UiColors? palette,
    UiTypography typography = UiTypography.standard,
  }) {
    final colors = palette ?? UiColors.fromSeed(seed, Brightness.light);
    return _build(colors, typography, Brightness.light);
  }

  /// 构建暗色主题（参数含义与 [light] 相同）。
  static ThemeData dark({
    Color seed = UiSeedPalette.teal,
    UiColors? palette,
    UiTypography typography = UiTypography.standard,
  }) {
    final colors = palette ?? UiColors.fromSeed(seed, Brightness.dark);
    return _build(colors, typography, Brightness.dark);
  }

  static ThemeData _build(
    UiColors palette,
    UiTypography typography,
    Brightness brightness,
  ) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: palette.brand,
      onPrimary: palette.textOnBrand,
      secondary: palette.brand,
      onSecondary: palette.textOnBrand,
      error: palette.danger,
      onError: palette.textOnBrand,
      surface: palette.surface,
      onSurface: palette.textPrimary,
    );

    final baseTextTheme = TextTheme(
      displayLarge: typography.largeTitle,
      displayMedium: typography.title1,
      displaySmall: typography.title2,
      headlineLarge: typography.title2,
      headlineMedium: typography.title3,
      headlineSmall: typography.headline,
      titleLarge: typography.title3,
      titleMedium: typography.headline,
      titleSmall: typography.callout,
      bodyLarge: typography.body,
      bodyMedium: typography.body,
      bodySmall: typography.subheadline,
      labelLarge: typography.button,
      labelMedium: typography.callout,
      labelSmall: typography.footnote,
    ).apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      dividerColor: palette.separator,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: palette.brandMuted.withValues(alpha: 0.4),
      textTheme: baseTextTheme,
      primaryTextTheme: baseTextTheme,
      visualDensity: VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[palette, typography],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle:
            typography.headline.copyWith(color: palette.textPrimary),
        iconTheme: IconThemeData(color: palette.brand, size: 22),
      ),
      iconTheme: IconThemeData(color: palette.textPrimary, size: 22),
      dividerTheme: DividerThemeData(
        color: palette.separator,
        thickness: 0.6,
        space: 0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.brand,
        linearMinHeight: 3,
      ),
      splashColor: Colors.transparent,
      // 全平台统一使用 iOS 风格的 Cupertino 页面过渡：
      // - 高性能（Flutter 内置实现，自带 parallax / 投影 / 边缘返回手势）；
      // - 与 UiMotion.page 使用同一底层 CupertinoPageTransition，push/pop
      //   手感一致；
      // - iOS 端保留原生手势返回，其它平台也获得一致体验。
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// 便于组件访问主题扩展的语法糖。
extension UiThemeAccess on BuildContext {
  UiColors get uiColors =>
      Theme.of(this).extension<UiColors>() ?? UiColors.light;
  UiTypography get uiType =>
      Theme.of(this).extension<UiTypography>() ?? UiTypography.standard;
}

import 'package:flutter/material.dart';

/// iOS 风格排版系统。
///
/// 字号对齐 Apple HIG 的 Body / Title / Large Title 等常用档位，
/// 字重采用 600（Semibold）/ 400（Regular）等常见 iOS 数值。
@immutable
class UiTypography extends ThemeExtension<UiTypography> {
  const UiTypography({
    required this.largeTitle,
    required this.title1,
    required this.title2,
    required this.title3,
    required this.headline,
    required this.body,
    required this.bodyEmphasized,
    required this.callout,
    required this.subheadline,
    required this.footnote,
    required this.caption,
    required this.button,
  });

  final TextStyle largeTitle;
  final TextStyle title1;
  final TextStyle title2;
  final TextStyle title3;
  final TextStyle headline;
  final TextStyle body;
  final TextStyle bodyEmphasized;
  final TextStyle callout;
  final TextStyle subheadline;
  final TextStyle footnote;
  final TextStyle caption;
  final TextStyle button;

  static const UiTypography standard = UiTypography(
    largeTitle: TextStyle(
      fontSize: 34,
      height: 1.18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    title1: TextStyle(
      fontSize: 28,
      height: 1.22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    title2: TextStyle(
      fontSize: 22,
      height: 1.26,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    title3: TextStyle(
      fontSize: 20,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    headline: TextStyle(
      fontSize: 17,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    body: TextStyle(
      fontSize: 16,
      height: 1.38,
      fontWeight: FontWeight.w400,
    ),
    bodyEmphasized: TextStyle(
      fontSize: 16,
      height: 1.38,
      fontWeight: FontWeight.w600,
    ),
    callout: TextStyle(
      fontSize: 15,
      height: 1.36,
      fontWeight: FontWeight.w500,
    ),
    subheadline: TextStyle(
      fontSize: 14,
      height: 1.36,
      fontWeight: FontWeight.w400,
    ),
    footnote: TextStyle(
      fontSize: 13,
      height: 1.32,
      fontWeight: FontWeight.w400,
    ),
    caption: TextStyle(
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w400,
    ),
    button: TextStyle(
      fontSize: 16,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
  );

  @override
  UiTypography copyWith({
    TextStyle? largeTitle,
    TextStyle? title1,
    TextStyle? title2,
    TextStyle? title3,
    TextStyle? headline,
    TextStyle? body,
    TextStyle? bodyEmphasized,
    TextStyle? callout,
    TextStyle? subheadline,
    TextStyle? footnote,
    TextStyle? caption,
    TextStyle? button,
  }) {
    return UiTypography(
      largeTitle: largeTitle ?? this.largeTitle,
      title1: title1 ?? this.title1,
      title2: title2 ?? this.title2,
      title3: title3 ?? this.title3,
      headline: headline ?? this.headline,
      body: body ?? this.body,
      bodyEmphasized: bodyEmphasized ?? this.bodyEmphasized,
      callout: callout ?? this.callout,
      subheadline: subheadline ?? this.subheadline,
      footnote: footnote ?? this.footnote,
      caption: caption ?? this.caption,
      button: button ?? this.button,
    );
  }

  @override
  UiTypography lerp(ThemeExtension<UiTypography>? other, double t) {
    if (other is! UiTypography) return this;
    return UiTypography(
      largeTitle: TextStyle.lerp(largeTitle, other.largeTitle, t)!,
      title1: TextStyle.lerp(title1, other.title1, t)!,
      title2: TextStyle.lerp(title2, other.title2, t)!,
      title3: TextStyle.lerp(title3, other.title3, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodyEmphasized: TextStyle.lerp(bodyEmphasized, other.bodyEmphasized, t)!,
      callout: TextStyle.lerp(callout, other.callout, t)!,
      subheadline: TextStyle.lerp(subheadline, other.subheadline, t)!,
      footnote: TextStyle.lerp(footnote, other.footnote, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      button: TextStyle.lerp(button, other.button, t)!,
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// 加载器尺寸规格。
enum UiLoaderSize { small, medium, large }

/// Material Design 风格加载器。
///
/// 采用 Flutter 自带的 [CircularProgressIndicator]，保留 Material 风格
/// 的匀速圆形旋转动画；提供尺寸预设与品牌色联动。
class UiLoader extends StatelessWidget {
  const UiLoader({
    super.key,
    this.size = UiLoaderSize.medium,
    this.color,
    this.strokeWidth,
    this.value,
  });

  final UiLoaderSize size;
  final Color? color;
  final double? strokeWidth;

  /// 若为 null 则为不确定进度；否则展示确定进度环。
  final double? value;

  @override
  Widget build(BuildContext context) {
    final dim = _dim();
    final color = this.color ?? context.uiColors.brand;
    return SizedBox(
      width: dim,
      height: dim,
      child: CircularProgressIndicator(
        value: value,
        strokeWidth: strokeWidth ?? _stroke(),
        valueColor: AlwaysStoppedAnimation<Color>(color),
        backgroundColor: color.withValues(alpha: 0.16),
      ),
    );
  }

  double _dim() {
    switch (size) {
      case UiLoaderSize.small:
        return 18;
      case UiLoaderSize.medium:
        return 28;
      case UiLoaderSize.large:
        return 40;
    }
  }

  double _stroke() {
    switch (size) {
      case UiLoaderSize.small:
        return 2;
      case UiLoaderSize.medium:
        return 3;
      case UiLoaderSize.large:
        return 3.6;
    }
  }
}

/// 全屏/局部遮罩加载。常用于异步操作。
class UiLoadingOverlay extends StatelessWidget {
  const UiLoadingOverlay({
    super.key,
    this.message,
    this.opacity = 0.32,
  });

  final String? message;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    return Container(
      color: Colors.black.withValues(alpha: opacity),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: UiSpacing.xl, vertical: UiSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: UiRadius.brLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const UiLoader(size: UiLoaderSize.large),
            if (message != null) ...[
              const SizedBox(height: UiSpacing.md),
              Text(message!,
                  style:
                      typography.callout.copyWith(color: colors.textPrimary)),
            ],
          ],
        ),
      ),
    );
  }
}

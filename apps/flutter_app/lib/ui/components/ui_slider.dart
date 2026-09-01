import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';

/// iOS18 风格滑块。底层仍使用 Flutter 内建 [Slider]，仅替换主题样式，
/// 因此滚动 / 手势行为与系统一致。
class UiSlider extends StatelessWidget {
  const UiSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    this.onChangeEnd,
    this.enabled = true,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: colors.brand,
        inactiveTrackColor: colors.separator,
        thumbColor: Colors.white,
        overlayColor: colors.brand.withValues(alpha: 0.08),
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 12,
          elevation: 2,
          pressedElevation: 4,
        ),
        valueIndicatorColor: colors.textPrimary,
        valueIndicatorTextStyle: TextStyle(
          color: colors.background,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        showValueIndicator: ShowValueIndicator.onlyForDiscrete,
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChanged: enabled ? onChanged : null,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

/// 区间滑块（同时拖拽两个把手选择范围）。
class UiRangeSlider extends StatelessWidget {
  const UiRangeSlider({
    super.key,
    required this.values,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.labels,
    this.enabled = true,
  });

  final RangeValues values;
  final ValueChanged<RangeValues>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final RangeLabels? labels;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: colors.brand,
        inactiveTrackColor: colors.separator,
        rangeThumbShape: const RoundRangeSliderThumbShape(
          enabledThumbRadius: 12,
          elevation: 2,
        ),
        rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
        overlayColor: colors.brand.withValues(alpha: 0.08),
        thumbColor: Colors.white,
      ),
      child: RangeSlider(
        values: values,
        min: min,
        max: max,
        divisions: divisions,
        labels: labels,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

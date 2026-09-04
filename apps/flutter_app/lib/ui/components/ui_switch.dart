import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// iOS18 风格开关（Toggle Switch）。
///
/// - 开：品牌色填充背景 + 白色圆形把手；
/// - 关：灰色轨道 + 白色把手；
/// - 触感反馈：切换时触发 `HapticFeedback.selectionClick`；
/// - 动画使用单一 [AnimatedContainer]，避免 ScaleTransition 带来的像素抖动。
class UiSwitch extends StatelessWidget {
  const UiSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.activeColor,
    this.enableHaptic = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final Color? activeColor;
  final bool enableHaptic;

  static const double _width = 51;
  static const double _height = 31;
  static const double _thumbSize = 27;
  static const double _padding = 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final active = activeColor ?? colors.success; // iOS 习惯用绿色
    final trackColor = value ? active : colors.separator;

    return Semantics(
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                if (enableHaptic) HapticFeedback.selectionClick();
                onChanged?.call(!value);
              }
            : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: UiDuration.base,
            curve: UiCurves.emphasized,
            width: _width,
            height: _height,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: UiRadius.brPill,
            ),
            padding: const EdgeInsets.all(_padding),
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: UiDuration.base,
                  curve: UiCurves.emphasized,
                  alignment: value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: colors.textOnBrand,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.overlay.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
import 'ui_icon.dart';

/// 数量加减步进器，用于购物车、表单数量等场景。
class UiStepper extends StatelessWidget {
  const UiStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
    this.step = 1,
    this.enabled = true,
    this.compact = false,
  });

  final int value;
  final ValueChanged<int>? onChanged;
  final int min;
  final int max;
  final int step;
  final bool enabled;
  final bool compact;

  bool get _canDec => enabled && value > min;
  bool get _canInc => enabled && value < max;

  void _set(int next) {
    if (!enabled) return;
    final clamped = next.clamp(min, max);
    if (clamped == value) return;
    HapticFeedback.selectionClick();
    onChanged?.call(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final h = compact ? 28.0 : 34.0;
    final iconSize = compact ? 14.0 : 16.0;

    Widget btn(IconData icon, bool enabled, VoidCallback onTap) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: h,
          height: h,
          child: Icon(
            icon,
            size: iconSize,
            color: enabled ? colors.brand : colors.textTertiary,
          ),
        ),
      );
    }

    return Container(
      height: h,
      decoration: BoxDecoration(
        color: colors.groupedBackground,
        borderRadius: UiRadius.brSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(UiIcons.minus, _canDec, () => _set(value - step)),
          Container(
            width: 0.6,
            height: h * 0.5,
            color: colors.separator,
          ),
          SizedBox(
            width: compact ? 28 : 36,
            child: Center(
              child: AnimatedSwitcher(
                duration: UiDuration.fast,
                transitionBuilder: (c, a) =>
                    FadeTransition(opacity: a, child: c),
                child: Text(
                  '$value',
                  key: ValueKey(value),
                  style: typography.callout.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 0.6,
            height: h * 0.5,
            color: colors.separator,
          ),
          btn(UiIcons.plus, _canInc, () => _set(value + step)),
        ],
      ),
    );
  }
}

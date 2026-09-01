import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
import 'ui_bottom_sheet.dart';
import 'ui_button.dart';
import 'ui_calendar.dart';
import 'ui_icon.dart';

/// 日期选择触发器：显示为一个类似输入框的按钮，点击后自底部弹出
/// [UiCalendar] 让用户选择日期。
class UiDatePicker extends StatefulWidget {
  const UiDatePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = '选择日期',
    this.label,
    this.minDate,
    this.maxDate,
    this.enabled = true,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String placeholder;
  final String? label;
  final DateTime? minDate;
  final DateTime? maxDate;
  final bool enabled;

  @override
  State<UiDatePicker> createState() => _UiDatePickerState();
}

class _UiDatePickerState extends State<UiDatePicker> {
  Future<void> _pick() async {
    DateTime? tentative = widget.value;
    await UiBottomSheet.show<void>(
      context,
      title: '选择日期',
      child: StatefulBuilder(
        builder: (ctx, setSheet) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiCalendar(
                initialDate: tentative,
                selectedDate: tentative,
                minDate: widget.minDate,
                maxDate: widget.maxDate,
                onChanged: (d) => setSheet(() => tentative = d),
              ),
              const SizedBox(height: UiSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: UiButton(
                      label: '清除',
                      variant: UiButtonVariant.secondary,
                      onPressed: () {
                        widget.onChanged(null);
                        Navigator.of(ctx).maybePop();
                      },
                    ),
                  ),
                  const SizedBox(width: UiSpacing.md),
                  Expanded(
                    child: UiButton(
                      label: '确定',
                      onPressed: () {
                        if (tentative != null) widget.onChanged(tentative);
                        Navigator.of(ctx).maybePop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _format(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final has = widget.value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!,
              style: typography.footnote
                  .copyWith(color: colors.textSecondary)),
          const SizedBox(height: UiSpacing.xs),
        ],
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? _pick : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: UiSpacing.md, vertical: UiSpacing.md),
            decoration: BoxDecoration(
              color: colors.groupedBackground,
              borderRadius: UiRadius.brMd,
            ),
            child: Row(
              children: [
                Icon(UiIcons.calendar, size: 18, color: colors.textSecondary),
                const SizedBox(width: UiSpacing.sm),
                Expanded(
                  child: Text(
                    has ? _format(widget.value!) : widget.placeholder,
                    style: typography.body.copyWith(
                      color: has ? colors.textPrimary : colors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(UiIcons.chevronRight,
                    size: 18, color: colors.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

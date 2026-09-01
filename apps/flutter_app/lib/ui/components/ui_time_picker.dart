import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
import 'ui_bottom_sheet.dart';
import 'ui_button.dart';
import 'ui_icon.dart';

/// iOS 风格的时间选择入口（输入框形态）。
///
/// 点击后从底部弹出 [UiBottomSheet]，内部用双列滚轮（时 + 分）选择时间。
/// 返回 [TimeOfDay]；支持 12/24 小时制与分钟步长。
class UiTimePicker extends StatelessWidget {
  const UiTimePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = '请选择时间',
    this.label,
    this.minuteInterval = 1,
    this.use24Hour = true,
    this.enabled = true,
  }) : assert(minuteInterval >= 1 && minuteInterval <= 30 && 60 % minuteInterval == 0,
            'minuteInterval 必须能被 60 整除');

  final TimeOfDay? value;
  final ValueChanged<TimeOfDay> onChanged;
  final String placeholder;
  final String? label;
  final int minuteInterval;
  final bool use24Hour;
  final bool enabled;

  String _format(TimeOfDay t) {
    if (use24Hour) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    final isPm = t.hour >= 12;
    final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '${h12.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} ${isPm ? 'PM' : 'AM'}';
  }

  Future<void> _open(BuildContext context) async {
    final result = await UiBottomSheet.show<TimeOfDay>(
      context,
      title: label ?? '选择时间',
      child: _TimeWheelPanel(
        initial: value ?? TimeOfDay.now(),
        minuteInterval: minuteInterval,
        use24Hour: use24Hour,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final display = value != null ? _format(value!) : placeholder;
    final hasValue = value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!,
              style: typography.footnote.copyWith(color: colors.textSecondary)),
          const SizedBox(height: UiSpacing.xs),
        ],
        Opacity(
          opacity: enabled ? 1 : 0.5,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => _open(context) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: UiSpacing.md, vertical: 12),
              decoration: BoxDecoration(
                color: colors.groupedBackground,
                borderRadius: UiRadius.brMd,
              ),
              child: Row(
                children: [
                  Icon(UiIcons.clock, size: 18, color: colors.textSecondary),
                  const SizedBox(width: UiSpacing.sm),
                  Expanded(
                    child: Text(
                      display,
                      style: typography.body.copyWith(
                        color: hasValue
                            ? colors.textPrimary
                            : colors.textTertiary,
                      ),
                    ),
                  ),
                  Icon(UiIcons.chevronRight,
                      size: 18, color: colors.textTertiary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeWheelPanel extends StatefulWidget {
  const _TimeWheelPanel({
    required this.initial,
    required this.minuteInterval,
    required this.use24Hour,
  });

  final TimeOfDay initial;
  final int minuteInterval;
  final bool use24Hour;

  @override
  State<_TimeWheelPanel> createState() => _TimeWheelPanelState();
}

class _TimeWheelPanelState extends State<_TimeWheelPanel> {
  late int _hour = widget.initial.hour;
  late int _minute =
      (widget.initial.minute ~/ widget.minuteInterval) * widget.minuteInterval;
  late bool _pm = widget.initial.hour >= 12;

  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minuteCtrl;
  late final FixedExtentScrollController _periodCtrl;

  @override
  void initState() {
    super.initState();
    final displayedHour =
        widget.use24Hour ? _hour : (_hour % 12 == 0 ? 12 : _hour % 12);
    final hourIndex = widget.use24Hour ? _hour : (displayedHour - 1);
    _hourCtrl = FixedExtentScrollController(initialItem: hourIndex);
    _minuteCtrl = FixedExtentScrollController(
        initialItem: _minute ~/ widget.minuteInterval);
    _periodCtrl = FixedExtentScrollController(initialItem: _pm ? 1 : 0);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _periodCtrl.dispose();
    super.dispose();
  }

  void _commit(BuildContext context) {
    int hour24;
    if (widget.use24Hour) {
      hour24 = _hour;
    } else {
      final h12 = _hour == 12 ? 0 : _hour;
      hour24 = _pm ? h12 + 12 : h12;
    }
    Navigator.of(context).pop(TimeOfDay(hour: hour24, minute: _minute));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final hoursCount = widget.use24Hour ? 24 : 12;
    final minutesList = List.generate(
        60 ~/ widget.minuteInterval, (i) => i * widget.minuteInterval);

    Widget wheel({
      required int itemCount,
      required FixedExtentScrollController controller,
      required ValueChanged<int> onSelected,
      required String Function(int) label,
    }) {
      return SizedBox(
        height: 180,
        child: ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 36,
          physics: const FixedExtentScrollPhysics(),
          perspective: 0.003,
          diameterRatio: 1.6,
          onSelectedItemChanged: onSelected,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: itemCount,
            builder: (context, i) => Center(
              child: Text(label(i),
                  style: typography.title3
                      .copyWith(color: colors.textPrimary)),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: UiSpacing.md),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 中线高亮
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: colors.brandMuted,
                  borderRadius: UiRadius.brSm,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: wheel(
                      itemCount: hoursCount,
                      controller: _hourCtrl,
                      onSelected: (i) {
                        setState(() {
                          if (widget.use24Hour) {
                            _hour = i;
                          } else {
                            final h12 = i + 1;
                            _hour = h12 == 12 ? 0 : h12;
                          }
                        });
                      },
                      label: (i) => widget.use24Hour
                          ? i.toString().padLeft(2, '0')
                          : (i + 1).toString().padLeft(2, '0'),
                    ),
                  ),
                  Text(':',
                      style: typography.title2
                          .copyWith(color: colors.textPrimary)),
                  Expanded(
                    child: wheel(
                      itemCount: minutesList.length,
                      controller: _minuteCtrl,
                      onSelected: (i) =>
                          setState(() => _minute = minutesList[i]),
                      label: (i) =>
                          minutesList[i].toString().padLeft(2, '0'),
                    ),
                  ),
                  if (!widget.use24Hour)
                    Expanded(
                      child: wheel(
                        itemCount: 2,
                        controller: _periodCtrl,
                        onSelected: (i) => setState(() => _pm = i == 1),
                        label: (i) => i == 0 ? 'AM' : 'PM',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: UiSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: UiSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: UiButton(
                  label: '取消',
                  variant: UiButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: UiSpacing.sm),
              Expanded(
                child: UiButton(
                  label: '确定',
                  onPressed: () => _commit(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

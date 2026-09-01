import 'package:flutter/material.dart';

import '../theme/ui_colors.dart';
import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
import '../theme/ui_typography.dart';
import 'ui_bottom_sheet.dart';
import 'ui_button.dart';
import 'ui_icon.dart';

/// 日期范围。
///
/// [start] / [end] 可能为 null，表示尚未完成选择：
/// - 都为 null：未开始；
/// - 只有 start：用户已选起点，等待选终点；
/// - 都有值：一次完整范围，保证 `start <= end`。
@immutable
class UiDateRange {
  const UiDateRange({this.start, this.end});

  final DateTime? start;
  final DateTime? end;

  bool get isComplete => start != null && end != null;

  UiDateRange copyWith({DateTime? start, DateTime? end}) =>
      UiDateRange(start: start ?? this.start, end: end ?? this.end);

  @override
  bool operator ==(Object other) =>
      other is UiDateRange &&
      _sameDay(other.start, start) &&
      _sameDay(other.end, end);

  @override
  int get hashCode => Object.hash(start, end);
}

bool _sameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return a == null && b == null;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

/// iOS18 风格日期范围选择器。
///
/// 交互：
/// - 第一次点击 → 设为起点；
/// - 第二次点击 → 若晚于起点则设为终点；若早于起点则重置为新起点；
/// - 起点/终点中间的日期会被高亮为"范围内"；
/// - 支持上下翻月、外部传入 [minDate]/[maxDate] 禁用超限日期。
///
/// 两种使用方式：
/// - 直接作为组件嵌入 `UiDateRangePicker(...)`；
/// - 通过 [UiDateRangePicker.show] 以 BottomSheet 方式弹出，返回 [UiDateRange]。
class UiDateRangePicker extends StatefulWidget {
  const UiDateRangePicker({
    super.key,
    this.initialRange,
    this.minDate,
    this.maxDate,
    this.onChanged,
    this.weekStart = DateTime.monday,
    this.maxWidth = 360,
  });

  final UiDateRange? initialRange;
  final DateTime? minDate;
  final DateTime? maxDate;
  final ValueChanged<UiDateRange>? onChanged;
  final int weekStart;

  /// 最大宽度，用于在无界约束（例如 Row 直接作为子节点）时防止内部
  /// `Row(Expanded)` 吃到无穷宽度后被放大成异常尺寸。传 `double.infinity`
  /// 可关闭该限制。
  final double maxWidth;

  /// 以底部抽屉方式弹出选择器，确认后返回范围。
  static Future<UiDateRange?> show(
    BuildContext context, {
    UiDateRange? initialRange,
    DateTime? minDate,
    DateTime? maxDate,
    String title = '选择日期范围',
    String confirmText = '确定',
    String resetText = '重置',
    int weekStart = DateTime.monday,
  }) {
    return UiBottomSheet.show<UiDateRange>(
      context,
      title: title,
      child: _RangeSheet(
        initialRange: initialRange,
        minDate: minDate,
        maxDate: maxDate,
        confirmText: confirmText,
        resetText: resetText,
        weekStart: weekStart,
      ),
    );
  }

  @override
  State<UiDateRangePicker> createState() => _UiDateRangePickerState();
}

class _UiDateRangePickerState extends State<UiDateRangePicker> {
  late DateTime _visible;
  DateTime? _start;
  DateTime? _end;
  DateTime? _hover;

  @override
  void initState() {
    super.initState();
    _start = widget.initialRange?.start;
    _end = widget.initialRange?.end;
    final base = _start ?? DateTime.now();
    _visible = DateTime(base.year, base.month);
  }

  @override
  void didUpdateWidget(covariant UiDateRangePicker old) {
    super.didUpdateWidget(old);
    if (widget.initialRange != old.initialRange) {
      _start = widget.initialRange?.start;
      _end = widget.initialRange?.end;
    }
  }

  void _goMonth(int delta) {
    setState(() {
      _visible = DateTime(_visible.year, _visible.month + delta);
    });
  }

  void _pick(DateTime d) {
    final day = _d(d);
    if (widget.minDate != null && day.isBefore(_d(widget.minDate!))) return;
    if (widget.maxDate != null && day.isAfter(_d(widget.maxDate!))) return;
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        _start = day;
        _end = null;
      } else if (_start != null && _end == null) {
        if (day.isBefore(_start!)) {
          _start = day;
        } else {
          _end = day;
        }
      }
    });
    widget.onChanged?.call(UiDateRange(start: _start, end: _end));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;

    return RepaintBoundary(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: Container(
          padding: const EdgeInsets.all(UiSpacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: UiRadius.brLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(
                visible: _visible,
                onPrev: () => _goMonth(-1),
                onNext: () => _goMonth(1),
              ),
              const SizedBox(height: UiSpacing.sm),
              _Summary(start: _start, end: _end),
              const SizedBox(height: UiSpacing.sm),
              _WeekdayRow(weekStart: widget.weekStart),
              const SizedBox(height: UiSpacing.xs),
              _MonthGrid(
                visible: _visible,
                start: _start,
                end: _end ?? _hover,
                minDate: widget.minDate,
                maxDate: widget.maxDate,
                weekStart: widget.weekStart,
                colors: colors,
                typography: typography,
                onTap: _pick,
                onHover: (d) {
                  if (_start != null && _end == null) {
                    setState(() => _hover = d);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.visible,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime visible;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    return Row(
      children: [
        UiButton.icon(
          icon: UiIcons.chevronLeft,
          variant: UiButtonVariant.ghost,
          size: UiButtonSize.small,
          onPressed: onPrev,
        ),
        Expanded(
          child: Center(
            child: Text(
              '${visible.year} 年 ${visible.month} 月',
              style:
                  typography.headline.copyWith(color: colors.textPrimary),
            ),
          ),
        ),
        UiButton.icon(
          icon: UiIcons.chevronRight,
          variant: UiButtonVariant.ghost,
          size: UiButtonSize.small,
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.start, required this.end});

  final DateTime? start;
  final DateTime? end;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    String fmt(DateTime? d) =>
        d == null ? '--' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final days = (start != null && end != null)
        ? end!.difference(start!).inDays + 1
        : null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Chip(label: '起', value: fmt(start), colors: colors, typography: typography),
        const SizedBox(width: UiSpacing.sm),
        Icon(UiIcons.arrowRight, size: 14, color: colors.textTertiary),
        const SizedBox(width: UiSpacing.sm),
        _Chip(label: '终', value: fmt(end), colors: colors, typography: typography),
        if (days != null) ...[
          const SizedBox(width: UiSpacing.md),
          Text('· 共 $days 天',
              style: typography.caption.copyWith(color: colors.textSecondary)),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.value,
    required this.colors,
    required this.typography,
  });
  final String label;
  final String value;
  final UiColors colors;
  final UiTypography typography;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: UiSpacing.sm, vertical: UiSpacing.xs),
      decoration: BoxDecoration(
        color: colors.groupedBackground,
        borderRadius: UiRadius.brSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: typography.caption.copyWith(color: colors.textTertiary)),
          const SizedBox(width: 4),
          Text(value,
              style: typography.body
                  .copyWith(color: colors.textPrimary, fontSize: 13.0)),
        ],
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.weekStart});
  final int weekStart;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    final rotated = <String>[];
    final offset = weekStart == DateTime.sunday ? 6 : 0;
    for (var i = 0; i < 7; i++) {
      rotated.add(labels[(i + offset) % 7]);
    }
    return Row(
      children: [
        for (final w in rotated)
          Expanded(
            child: Center(
              child: Text(
                w,
                style: typography.caption.copyWith(
                  color: colors.textTertiary,
                  fontSize: 11.0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.visible,
    required this.start,
    required this.end,
    required this.minDate,
    required this.maxDate,
    required this.weekStart,
    required this.colors,
    required this.typography,
    required this.onTap,
    required this.onHover,
  });

  final DateTime visible;
  final DateTime? start;
  final DateTime? end;
  final DateTime? minDate;
  final DateTime? maxDate;
  final int weekStart;
  final UiColors colors;
  final UiTypography typography;
  final ValueChanged<DateTime> onTap;
  final ValueChanged<DateTime?> onHover;

  int _daysInMonth(int y, int m) {
    if (m == 2) {
      final leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;
      return leap ? 29 : 28;
    }
    if ([1, 3, 5, 7, 8, 10, 12].contains(m)) return 31;
    return 30;
  }

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(visible.year, visible.month, 1).weekday;
    final shift = weekStart == DateTime.monday ? 1 : 7;
    final leading = (firstWeekday - shift + 7) % 7;
    final daysInMonth = _daysInMonth(visible.year, visible.month);
    final totalCells = ((leading + daysInMonth) / 7).ceil() * 7;

    final cells = <Widget>[];
    for (var i = 0; i < totalCells; i++) {
      final day = i - leading + 1;
      if (day < 1 || day > daysInMonth) {
        cells.add(const SizedBox());
        continue;
      }
      final date = DateTime(visible.year, visible.month, day);
      cells.add(_Cell(
        date: date,
        start: start,
        end: end,
        minDate: minDate,
        maxDate: maxDate,
        colors: colors,
        typography: typography,
        onTap: onTap,
        onHover: onHover,
      ));
    }

    return Column(
      children: [
        for (var r = 0; r < cells.length / 7; r++)
          SizedBox(
            height: 40,
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(child: cells[r * 7 + c]),
              ],
            ),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.date,
    required this.start,
    required this.end,
    required this.minDate,
    required this.maxDate,
    required this.colors,
    required this.typography,
    required this.onTap,
    required this.onHover,
  });

  final DateTime date;
  final DateTime? start;
  final DateTime? end;
  final DateTime? minDate;
  final DateTime? maxDate;
  final UiColors colors;
  final UiTypography typography;
  final ValueChanged<DateTime> onTap;
  final ValueChanged<DateTime?> onHover;

  bool _inRange() {
    if (start == null || end == null) return false;
    final s = _d(start!);
    final e = _d(end!);
    final d = _d(date);
    final lo = s.isBefore(e) ? s : e;
    final hi = s.isBefore(e) ? e : s;
    return !d.isBefore(lo) && !d.isAfter(hi);
  }

  @override
  Widget build(BuildContext context) {
    final isStart = _sameDay(date, start);
    final isEnd = _sameDay(date, end);
    final isEdge = isStart || isEnd;
    final inRange = _inRange();
    final today = _sameDay(date, DateTime.now());

    final disabled = (minDate != null && _d(date).isBefore(_d(minDate!))) ||
        (maxDate != null && _d(date).isAfter(_d(maxDate!)));

    final bgRange = colors.brandSoft;
    final bgEdge = colors.brand;

    Color textColor;
    if (disabled) {
      textColor = colors.textTertiary;
    } else if (isEdge) {
      textColor = Colors.white;
    } else if (inRange) {
      textColor = colors.brand;
    } else {
      textColor = colors.textPrimary;
    }

    // 范围的左右半背景，用于在两端之间连成一条横向高亮带。
    final bothEnds = start != null && end != null;
    final s = bothEnds ? (_d(start!).isBefore(_d(end!)) ? start! : end!) : null;
    final e = bothEnds ? (_d(start!).isBefore(_d(end!)) ? end! : start!) : null;
    final isLeft = s != null && _sameDay(date, s);
    final isRight = e != null && _sameDay(date, e);

    return MouseRegion(
      onEnter: (_) => onHover(date),
      onExit: (_) => onHover(null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: disabled ? null : () => onTap(date),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (inRange && !isEdge)
              Container(color: bgRange),
            if (isEdge && bothEnds)
              Row(
                children: [
                  Expanded(child: Container(color: isLeft ? Colors.transparent : bgRange)),
                  Expanded(child: Container(color: isRight ? Colors.transparent : bgRange)),
                ],
              ),
            if (isEdge)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: bgEdge,
                  borderRadius: UiRadius.brPill,
                ),
              ),
            if (today && !isEdge)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.brand,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Text(
              '${date.day}',
              style: typography.body.copyWith(
                color: textColor,
                fontSize: 14.0,
                fontWeight: isEdge ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// BottomSheet 版本的壳：内嵌 Picker + 底部确认栏。
class _RangeSheet extends StatefulWidget {
  const _RangeSheet({
    required this.initialRange,
    required this.minDate,
    required this.maxDate,
    required this.confirmText,
    required this.resetText,
    required this.weekStart,
  });

  final UiDateRange? initialRange;
  final DateTime? minDate;
  final DateTime? maxDate;
  final String confirmText;
  final String resetText;
  final int weekStart;

  @override
  State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  UiDateRange _range = const UiDateRange();

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange ?? const UiDateRange();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        UiDateRangePicker(
          initialRange: _range,
          minDate: widget.minDate,
          maxDate: widget.maxDate,
          weekStart: widget.weekStart,
          onChanged: (r) => setState(() => _range = r),
        ),
        const SizedBox(height: UiSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: UiSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: UiButton(
                  label: widget.resetText,
                  variant: UiButtonVariant.secondary,
                  onPressed: () =>
                      setState(() => _range = const UiDateRange()),
                ),
              ),
              const SizedBox(width: UiSpacing.md),
              Expanded(
                child: UiButton(
                  label: widget.confirmText,
                  onPressed: _range.isComplete
                      ? () => Navigator.of(context).pop(_range)
                      : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: UiSpacing.md),
      ],
    );
  }
}

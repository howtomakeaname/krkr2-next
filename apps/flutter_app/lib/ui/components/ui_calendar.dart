import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
import 'ui_button.dart';
import 'ui_icon.dart';

/// 日历工具：抽出的无状态帮助函数，便于单测/复用。
class _CalendarUtils {
  static int daysInMonth(int year, int month) {
    if (month == 2) {
      final leap =
          (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return leap ? 29 : 28;
    }
    if ([1, 3, 5, 7, 8, 10, 12].contains(month)) return 31;
    return 30;
  }

  static int firstDayWeekday(int year, int month) {
    return DateTime(year, month, 1).weekday; // 1..7
  }

  static bool sameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

/// iOS18 风格日历组件。
///
/// 顶部 "‹ 年-月 ›" 可以切换月份；点击标题在 "日 → 月 → 年" 三种模式
/// 之间循环切换。
///
/// 动效：
/// - 同模式下翻页：水平滑入滑出（`SlideTransition`）；
/// - 模式切换：缩放 + 透明度混合（`ScaleTransition + FadeTransition`）。
class UiCalendar extends StatefulWidget {
  const UiCalendar({
    super.key,
    this.initialDate,
    this.selectedDate,
    this.minDate,
    this.maxDate,
    this.onChanged,
    this.weekStart = DateTime.monday,
    this.showWeekdayHeader = true,
  });

  final DateTime? initialDate;
  final DateTime? selectedDate;
  final DateTime? minDate;
  final DateTime? maxDate;
  final ValueChanged<DateTime>? onChanged;

  /// 周起始日：[DateTime.monday] 或 [DateTime.sunday]。
  final int weekStart;
  final bool showWeekdayHeader;

  @override
  State<UiCalendar> createState() => _UiCalendarState();
}

enum _CalendarMode { day, month, year }

/// 翻页方向：用于决定水平滑动动画的起始位置。
enum _SlideDirection { none, forward, backward }

class _UiCalendarState extends State<UiCalendar> {
  late DateTime _visible;
  late DateTime? _selected;
  _CalendarMode _mode = _CalendarMode.day;
  _SlideDirection _direction = _SlideDirection.none;
  bool _isModeSwitching = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedDate;
    final init = widget.initialDate ?? widget.selectedDate ?? DateTime.now();
    _visible = DateTime(init.year, init.month);
  }

  @override
  void didUpdateWidget(covariant UiCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      _selected = widget.selectedDate;
    }
  }

  void _goPrev() {
    setState(() {
      _direction = _SlideDirection.backward;
      _isModeSwitching = false;
      if (_mode == _CalendarMode.day) {
        _visible = DateTime(_visible.year, _visible.month - 1);
      } else if (_mode == _CalendarMode.month) {
        _visible = DateTime(_visible.year - 1, _visible.month);
      } else {
        _visible = DateTime(_visible.year - 12, _visible.month);
      }
    });
  }

  void _goNext() {
    setState(() {
      _direction = _SlideDirection.forward;
      _isModeSwitching = false;
      if (_mode == _CalendarMode.day) {
        _visible = DateTime(_visible.year, _visible.month + 1);
      } else if (_mode == _CalendarMode.month) {
        _visible = DateTime(_visible.year + 1, _visible.month);
      } else {
        _visible = DateTime(_visible.year + 12, _visible.month);
      }
    });
  }

  void _cycleMode() {
    setState(() {
      _isModeSwitching = true;
      _direction = _SlideDirection.none;
      _mode = _CalendarMode.values[(_mode.index + 1) % 3];
    });
  }

  void _pickDate(DateTime d) {
    if (widget.minDate != null && d.isBefore(widget.minDate!)) return;
    if (widget.maxDate != null && d.isAfter(widget.maxDate!)) return;
    setState(() => _selected = d);
    widget.onChanged?.call(d);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(UiSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: UiRadius.brLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(colors, typography),
            const SizedBox(height: UiSpacing.sm),
            ClipRect(
              child: AnimatedSwitcher(
                duration: UiDuration.base,
                switchInCurve: UiCurves.emphasized,
                switchOutCurve: UiCurves.standard,
                layoutBuilder: (current, previous) {
                  // 让进入/离开动画期间两个 body 重叠，保证平滑。
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      ...previous,
                      if (current != null) current,
                    ],
                  );
                },
                transitionBuilder: _transitionBuilder,
                child: _buildBody(colors, typography),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transitionBuilder(Widget child, Animation<double> animation) {
    // 模式切换：缩放 + 淡入/淡出，进出在同一位置重叠，因此依靠不透明度
    // 区分前后层次。
    if (_isModeSwitching) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
          child: child,
        ),
      );
    }

    // 水平翻页：
    // - AnimatedSwitcher 会对 incoming child 的 animation 正向运行（0→1），
    //   对 outgoing child 反向运行（1→0），两者使用同一个 transitionBuilder。
    // - 我们通过 animation.status 判断当前是 incoming 还是 outgoing，
    //   让 outgoing **反向滑出**、incoming **正向滑入**，从而在视觉上
    //   完全错开、不再重影。
    final outgoing = animation.status == AnimationStatus.reverse ||
        animation.status == AnimationStatus.dismissed;
    final backward = _direction == _SlideDirection.backward;

    // 偏移幅度用 1.0（容器宽度），并配合外层 ClipRect 做硬裁剪，
    // 使滑出部分不会溢出到父容器。
    final Offset tweenBegin;
    if (outgoing) {
      // outgoing 的 animation 1→0，Tween(begin→end=0) 效果为 0→begin，
      // 因此 begin 需要设为离开方向。
      tweenBegin = Offset(backward ? 1.0 : -1.0, 0);
    } else {
      // incoming 的 animation 0→1，Tween(begin→end=0) 效果为 begin→0。
      tweenBegin = Offset(backward ? -1.0 : 1.0, 0);
    }

    return SlideTransition(
      position: Tween<Offset>(begin: tweenBegin, end: Offset.zero)
          .animate(CurvedAnimation(
        parent: animation,
        curve: UiCurves.emphasized,
        reverseCurve: UiCurves.emphasized,
      )),
      child: child,
    );
  }

  Widget _buildHeader(colors, typography) {
    final title = _mode == _CalendarMode.day
        ? '${_visible.year} 年 ${_visible.month} 月'
        : _mode == _CalendarMode.month
            ? '${_visible.year} 年'
            : '${_visible.year - 6} - ${_visible.year + 5}';
    return Row(
      children: [
        UiButton.icon(
          icon: UiIcons.chevronLeft,
          variant: UiButtonVariant.ghost,
          size: UiButtonSize.small,
          onPressed: _goPrev,
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _cycleMode,
            child: Center(
              child: AnimatedSwitcher(
                duration: UiDuration.fast,
                transitionBuilder: (c, a) =>
                    FadeTransition(opacity: a, child: c),
                child: Text(
                  title,
                  key: ValueKey(title),
                  style: typography.headline
                      .copyWith(color: colors.textPrimary),
                ),
              ),
            ),
          ),
        ),
        UiButton.icon(
          icon: UiIcons.chevronRight,
          variant: UiButtonVariant.ghost,
          size: UiButtonSize.small,
          onPressed: _goNext,
        ),
      ],
    );
  }

  Widget _buildBody(colors, typography) {
    switch (_mode) {
      case _CalendarMode.day:
        return KeyedSubtree(
          key: ValueKey('day-${_visible.year}-${_visible.month}'),
          child: _DayGrid(
            visible: _visible,
            selected: _selected,
            minDate: widget.minDate,
            maxDate: widget.maxDate,
            weekStart: widget.weekStart,
            showWeekdayHeader: widget.showWeekdayHeader,
            onPick: _pickDate,
          ),
        );
      case _CalendarMode.month:
        return KeyedSubtree(
          key: ValueKey('month-${_visible.year}'),
          child: _MonthGrid(
            visible: _visible,
            selected: _selected,
            onPick: (month) {
              setState(() {
                _isModeSwitching = true;
                _visible = DateTime(_visible.year, month);
                _mode = _CalendarMode.day;
              });
            },
          ),
        );
      case _CalendarMode.year:
        return KeyedSubtree(
          key: ValueKey('year-${_visible.year}'),
          child: _YearGrid(
            visible: _visible,
            selected: _selected,
            onPick: (year) {
              setState(() {
                _isModeSwitching = true;
                _visible = DateTime(year, _visible.month);
                _mode = _CalendarMode.month;
              });
            },
          ),
        );
    }
  }
}

class _DayGrid extends StatelessWidget {
  const _DayGrid({
    required this.visible,
    required this.selected,
    required this.minDate,
    required this.maxDate,
    required this.weekStart,
    required this.showWeekdayHeader,
    required this.onPick,
  });

  final DateTime visible;
  final DateTime? selected;
  final DateTime? minDate;
  final DateTime? maxDate;
  final int weekStart;
  final bool showWeekdayHeader;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;

    final weekdayLabels = weekStart == DateTime.monday
        ? ['一', '二', '三', '四', '五', '六', '日']
        : ['日', '一', '二', '三', '四', '五', '六'];

    final firstDow =
        _CalendarUtils.firstDayWeekday(visible.year, visible.month);
    final leading =
        weekStart == DateTime.monday ? (firstDow - 1) : (firstDow % 7);
    final days =
        _CalendarUtils.daysInMonth(visible.year, visible.month);
    final total = leading + days;
    final rows = (total / 7).ceil();

    return Column(
      children: [
        if (showWeekdayHeader)
          Padding(
            padding: const EdgeInsets.only(bottom: UiSpacing.xs),
            child: Row(
              children: [
                for (final w in weekdayLabels)
                  Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: typography.caption.copyWith(
                            color: colors.textTertiary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        for (int r = 0; r < rows; r++)
          Row(
            children: [
              for (int c = 0; c < 7; c++)
                Expanded(
                    child: _buildDayCell(
                        r, c, leading, days, colors, typography)),
            ],
          ),
      ],
    );
  }

  Widget _buildDayCell(
      int row, int col, int leading, int days, colors, typography) {
    final i = row * 7 + col;
    final dayNum = i - leading + 1;
    if (dayNum < 1 || dayNum > days) {
      return const SizedBox(height: 40);
    }
    final date = DateTime(visible.year, visible.month, dayNum);
    final isSelected = _CalendarUtils.sameDate(date, selected);
    final today = _CalendarUtils.sameDate(date, DateTime.now());
    final disabled = (minDate != null && date.isBefore(minDate!)) ||
        (maxDate != null && date.isAfter(maxDate!));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : () => onPick(date),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: UiDuration.fast,
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? colors.brand
                : today
                    ? colors.brandMuted
                    : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$dayNum',
            style: typography.body.copyWith(
              color: disabled
                  ? colors.textTertiary
                  : isSelected
                      ? colors.textOnBrand
                      : today
                          ? colors.brand
                          : colors.textPrimary,
              fontWeight:
                  isSelected || today ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.visible,
    required this.selected,
    required this.onPick,
  });

  final DateTime visible;
  final DateTime? selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2,
      children: List.generate(12, (i) {
        final month = i + 1;
        final isSelected = selected != null &&
            selected!.year == visible.year &&
            selected!.month == month;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onPick(month),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: UiSpacing.md, vertical: UiSpacing.sm),
              decoration: BoxDecoration(
                color: isSelected ? colors.brand : Colors.transparent,
                borderRadius: UiRadius.brPill,
              ),
              child: Text('$month 月',
                  style: typography.callout.copyWith(
                    color: isSelected
                        ? colors.textOnBrand
                        : colors.textPrimary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                  )),
            ),
          ),
        );
      }),
    );
  }
}

class _YearGrid extends StatelessWidget {
  const _YearGrid({
    required this.visible,
    required this.selected,
    required this.onPick,
  });

  final DateTime visible;
  final DateTime? selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final startYear = visible.year - 6;
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2,
      children: List.generate(12, (i) {
        final year = startYear + i;
        final isSelected = selected != null && selected!.year == year;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onPick(year),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: UiSpacing.md, vertical: UiSpacing.sm),
              decoration: BoxDecoration(
                color: isSelected ? colors.brand : Colors.transparent,
                borderRadius: UiRadius.brPill,
              ),
              child: Text('$year',
                  style: typography.callout.copyWith(
                    color: isSelected
                        ? colors.textOnBrand
                        : colors.textPrimary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                  )),
            ),
          ),
        );
      }),
    );
  }
}

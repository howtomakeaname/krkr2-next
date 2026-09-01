import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ui_theme.dart';

/// 星级评分组件。
///
/// - [value]：当前评分，[0, count]，支持小数（半星/自定义精度）；
/// - [readOnly] = true：仅展示；
/// - 拖动手指可以快速调整分值，抬手触发 [onChanged]；
/// - [allowHalf] = true：支持 0.5 步进；默认 1 步进；
/// - [color]：星星高亮色，默认为主题品牌色。
class UiRating extends StatefulWidget {
  const UiRating({
    super.key,
    required this.value,
    this.onChanged,
    this.count = 5,
    this.size = 24,
    this.gap = 4,
    this.readOnly = false,
    this.allowHalf = true,
    this.color,
    this.emptyColor,
    this.enableHaptic = true,
  })  : assert(count >= 1),
        assert(value >= 0);

  final double value;
  final ValueChanged<double>? onChanged;
  final int count;
  final double size;
  final double gap;
  final bool readOnly;
  final bool allowHalf;
  final Color? color;
  final Color? emptyColor;
  final bool enableHaptic;

  @override
  State<UiRating> createState() => _UiRatingState();
}

class _UiRatingState extends State<UiRating> {
  double? _previewValue;

  double get _displayValue => _previewValue ?? widget.value;

  void _updateByPosition(Offset localPosition, Size size) {
    final totalWidth = widget.count * widget.size +
        (widget.count - 1) * widget.gap;
    final clamped = localPosition.dx.clamp(0.0, totalWidth);
    final unit = widget.size + widget.gap;
    // 落在第几颗星，以及在这颗星里的水平位置比例
    final idx = (clamped / unit).floor().clamp(0, widget.count - 1);
    final within = (clamped - idx * unit).clamp(0, widget.size) / widget.size;
    double raw;
    if (widget.allowHalf) {
      raw = idx + (within < 0.5 ? 0.5 : 1.0);
    } else {
      raw = idx + (within < 1.0 ? 1.0 : 1.0);
    }
    raw = raw.clamp(widget.allowHalf ? 0.5 : 1.0, widget.count.toDouble());

    if (_displayValue != raw) {
      if (widget.enableHaptic) HapticFeedback.selectionClick();
      setState(() => _previewValue = raw);
    }
  }

  void _commit() {
    final preview = _previewValue;
    setState(() => _previewValue = null);
    if (preview != null) {
      widget.onChanged?.call(preview);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final filled = widget.color ?? colors.warning;
    final empty = widget.emptyColor ?? colors.separator;
    final interactive = !widget.readOnly && widget.onChanged != null;

    final stars = List<Widget>.generate(widget.count, (i) {
      final v = _displayValue - i;
      final double fill = v <= 0
          ? 0
          : v >= 1
              ? 1
              : widget.allowHalf
                  ? (v < 0.5 ? 0 : 0.5)
                  : (v < 1 ? 0 : 1);
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: _Star(size: widget.size, fill: fill, filled: filled, empty: empty),
      );
    });

    Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < stars.length; i++) ...[
          if (i != 0) SizedBox(width: widget.gap),
          stars[i],
        ],
      ],
    );

    if (!interactive) return row;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        _updateByPosition(
          d.localPosition,
          Size(
            widget.count * widget.size + (widget.count - 1) * widget.gap,
            widget.size,
          ),
        );
      },
      onHorizontalDragUpdate: (d) {
        _updateByPosition(
          d.localPosition,
          Size(
            widget.count * widget.size + (widget.count - 1) * widget.gap,
            widget.size,
          ),
        );
      },
      onHorizontalDragEnd: (_) => _commit(),
      onTapUp: (_) => _commit(),
      onTapCancel: _commit,
      child: row,
    );
  }
}

/// 单颗星：使用 Material 内建的实心 / 半填 / 边框三态图标，
/// 保证在任意主题下都显示正确的"已填充"形态。
class _Star extends StatelessWidget {
  const _Star({
    required this.size,
    required this.fill,
    required this.filled,
    required this.empty,
  });

  final double size;
  final double fill; // 0 / 0.5 / 1
  final Color filled;
  final Color empty;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    if (fill >= 1) {
      icon = Icons.star_rounded;
      color = filled;
    } else if (fill >= 0.5) {
      icon = Icons.star_half_rounded;
      color = filled;
    } else {
      icon = Icons.star_outline_rounded;
      color = empty;
    }
    return Icon(icon, size: size, color: color);
  }
}

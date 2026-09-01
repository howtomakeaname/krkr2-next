import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
import 'ui_icon.dart';

/// iOS18 风格列表项。
///
/// 既可作为单行列表（仅 [title]），也可作为多行列表（同时提供
/// [title] 和 [subtitle]），前置支持自定义 [leading] 或 [icon]，
/// 尾部支持 [trailing]（可以是开关、文本值、箭头等）。
///
/// 当 [onTap] 或 [onLongPress] 存在时，会展示按压反馈。
class UiListTile extends StatefulWidget {
  const UiListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.icon,
    this.iconColor,
    this.iconBackground,
    this.trailing,
    this.trailingText,
    this.showChevron = false,
    this.onTap,
    this.onLongPress,
    this.dense = false,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackground;
  final Widget? trailing;
  final String? trailingText;
  final bool showChevron;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool dense;
  final EdgeInsetsGeometry? padding;

  @override
  State<UiListTile> createState() => _UiListTileState();
}

class _UiListTileState extends State<UiListTile> {
  bool _pressed = false;

  bool get _tappable => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool v) {
    if (!_tappable) return;
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;

    final Widget? leading = _buildLeading(colors);
    final trailing = _buildTrailing(colors, typography);

    final body = Row(
      children: [
        if (leading != null) ...[
          leading,
          const SizedBox(width: UiSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                style: typography.body.copyWith(color: colors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  widget.subtitle!,
                  style: typography.footnote
                      .copyWith(color: colors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: UiSpacing.md),
          trailing,
        ],
      ],
    );

    // 外层 RepaintBoundary：在长列表中，每行的按压态重绘不会污染其他行。
    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: UiDuration.fast,
          curve: UiCurves.standard,
          color: _pressed ? colors.surfacePressed : Colors.transparent,
          padding: widget.padding ??
              EdgeInsets.symmetric(
                horizontal: UiSpacing.lg,
                vertical: widget.dense ? UiSpacing.sm : UiSpacing.md,
              ),
          child: body,
        ),
      ),
    );
  }

  Widget? _buildLeading(colors) {
    if (widget.leading != null) return widget.leading;
    if (widget.icon == null) return null;
    final bg = widget.iconBackground ?? colors.brandSoft;
    final fg = widget.iconColor ?? colors.brand;
    return Container(
      width: widget.dense ? 30 : 34,
      height: widget.dense ? 30 : 34,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: UiRadius.brSm,
      ),
      alignment: Alignment.center,
      child: Icon(widget.icon, size: widget.dense ? 16 : 18, color: fg),
    );
  }

  Widget? _buildTrailing(colors, typography) {
    final widgets = <Widget>[];
    if (widget.trailingText != null) {
      widgets.add(Text(
        widget.trailingText!,
        style: typography.footnote.copyWith(color: colors.textSecondary),
      ));
    }
    if (widget.trailing != null) widgets.add(widget.trailing!);
    if (widget.showChevron) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(width: UiSpacing.xs));
      widgets.add(UiIcon(UiIcons.chevronRight,
          size: 16, color: colors.textTertiary));
    }
    if (widgets.isEmpty) return null;
    return Row(mainAxisSize: MainAxisSize.min, children: widgets);
  }
}

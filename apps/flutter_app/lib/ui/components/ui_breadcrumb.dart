import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

class UiBreadcrumbItem {
  const UiBreadcrumbItem({required this.label, this.icon, this.onTap});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
}

/// 面包屑导航。
///
/// - 水平滚动，避免窄屏下溢出；
/// - 路径变长或变短后，自动滚到当前（最后一项），避免用手拖滚动条；
/// - 最后一项高亮为 textPrimary 且不可点击；
/// - 支持自定义分隔符（默认 `›`）。
class UiBreadcrumb extends StatefulWidget {
  const UiBreadcrumb({
    super.key,
    required this.items,
    this.separator = '›',
    this.maxLines = 1,
  }) : assert(items.length > 0);

  final List<UiBreadcrumbItem> items;
  final String separator;
  final int maxLines;

  @override
  State<UiBreadcrumb> createState() => _UiBreadcrumbState();
}

class _UiBreadcrumbState extends State<UiBreadcrumb> {
  final _controller = ScrollController();
  final _currentKey = GlobalKey();
  var _firstReveal = true;

  @override
  void initState() {
    super.initState();
    _scheduleReveal();
  }

  @override
  void didUpdateWidget(covariant UiBreadcrumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_signature(oldWidget.items) != _signature(widget.items)) {
      _scheduleReveal();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _signature(List<UiBreadcrumbItem> items) =>
      items.map((item) => item.label).join('\u0001');

  void _scheduleReveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _currentKey.currentContext;
      if (target == null) return;
      final animate = !_firstReveal && !MediaQuery.disableAnimationsOf(context);
      _firstReveal = false;
      Scrollable.ensureVisible(
        target,
        alignment: 1,
        duration: animate ? UiDuration.base : Duration.zero,
        curve: UiCurves.iosStandard,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;

    final widgets = <Widget>[];
    for (int i = 0; i < widget.items.length; i++) {
      final isLast = i == widget.items.length - 1;
      final item = widget.items[i];
      widgets.add(
        _Crumb(
          key: isLast ? _currentKey : null,
          label: item.label,
          icon: item.icon,
          isLast: isLast,
          onTap: isLast ? null : item.onTap,
        ),
      );
      if (!isLast) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: UiSpacing.xs),
            child: Text(
              widget.separator,
              style: typography.subheadline.copyWith(
                color: colors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }
    }

    return SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: widgets,
      ),
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({
    super.key,
    required this.label,
    required this.icon,
    required this.isLast,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final style = typography.subheadline.copyWith(
      color: isLast
          ? colors.textPrimary
          : (onTap != null ? colors.brand : colors.textSecondary),
      fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: style.color),
          const SizedBox(width: 4),
        ],
        Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: content,
        ),
      ),
    );
  }
}

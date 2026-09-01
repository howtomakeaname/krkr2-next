import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
import 'ui_icon.dart';

/// 单个折叠面板。
///
/// 默认展开/折叠由自身状态管理；也可传入 [expanded] + [onChanged] 做受控。
/// 面板高度变化使用 [AnimatedSize] + [AnimatedRotation]（箭头）组合呈现。
class UiCollapse extends StatefulWidget {
  const UiCollapse({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.initialExpanded = false,
    this.expanded,
    this.onChanged,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(
        horizontal: UiSpacing.lg, vertical: UiSpacing.md),
    this.contentPadding = const EdgeInsets.fromLTRB(
        UiSpacing.lg, 0, UiSpacing.lg, UiSpacing.md),
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget child;

  /// 非受控初值。
  final bool initialExpanded;

  /// 受控展开态（与 [onChanged] 搭配）。
  final bool? expanded;
  final ValueChanged<bool>? onChanged;

  /// 自定义 trailing，未提供时显示旋转箭头。
  final Widget? trailing;

  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry contentPadding;

  @override
  State<UiCollapse> createState() => _UiCollapseState();
}

class _UiCollapseState extends State<UiCollapse> {
  late bool _expanded = widget.expanded ?? widget.initialExpanded;

  bool get _isExpanded => widget.expanded ?? _expanded;

  void _toggle() {
    final next = !_isExpanded;
    if (widget.expanded == null) {
      setState(() => _expanded = next);
    }
    widget.onChanged?.call(next);
  }

  @override
  void didUpdateWidget(covariant UiCollapse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != null && widget.expanded != oldWidget.expanded) {
      setState(() => _expanded = widget.expanded!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    return ClipRect(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: Padding(
              padding: widget.padding,
              child: Row(
                children: [
                  if (widget.leading != null) ...[
                    widget.leading!,
                    const SizedBox(width: UiSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.title,
                            style: typography.headline
                                .copyWith(color: colors.textPrimary)),
                        if (widget.subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(widget.subtitle!,
                                style: typography.footnote.copyWith(
                                    color: colors.textSecondary)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: UiSpacing.sm),
                  widget.trailing ??
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: UiDuration.base,
                        curve: UiCurves.emphasized,
                        child: Icon(UiIcons.chevronDown,
                            size: 18, color: colors.textTertiary),
                      ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: UiDuration.base,
            curve: UiCurves.emphasized,
            alignment: Alignment.topCenter,
            child: _isExpanded
                ? Padding(
                    padding: widget.contentPadding,
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// 折叠面板组（Accordion）。
///
/// [exclusive] 为 true 时同时只有一个面板展开；false 时可以并行展开多个。
class UiCollapseGroup extends StatefulWidget {
  const UiCollapseGroup({
    super.key,
    required this.children,
    this.exclusive = true,
    this.initialExpandedIndex,
  });

  final List<UiCollapse> children;
  final bool exclusive;
  final int? initialExpandedIndex;

  @override
  State<UiCollapseGroup> createState() => _UiCollapseGroupState();
}

class _UiCollapseGroupState extends State<UiCollapseGroup> {
  late Set<int> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = {
      if (widget.initialExpandedIndex != null) widget.initialExpandedIndex!,
    };
  }

  void _toggle(int i, bool next) {
    setState(() {
      if (widget.exclusive) {
        _expanded = next ? {i} : {};
      } else {
        if (next) {
          _expanded.add(i);
        } else {
          _expanded.remove(i);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.children.length; i++) ...[
          UiCollapse(
            title: widget.children[i].title,
            subtitle: widget.children[i].subtitle,
            leading: widget.children[i].leading,
            trailing: widget.children[i].trailing,
            padding: widget.children[i].padding,
            contentPadding: widget.children[i].contentPadding,
            expanded: _expanded.contains(i),
            onChanged: (v) => _toggle(i, v),
            child: widget.children[i].child,
          ),
          if (i != widget.children.length - 1)
            Divider(
              height: 0.6,
              thickness: 0.6,
              color: colors.separator,
              indent: UiSpacing.lg,
            ),
        ],
      ],
    );
  }
}

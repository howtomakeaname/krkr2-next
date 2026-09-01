import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
import 'ui_icon.dart';

/// 下拉选项。
class UiDropdownItem<T> {
  const UiDropdownItem({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// iOS18 风格下拉选择器。
///
/// 点击后弹出 popup 面板，支持最大高度约束与滚动。
class UiDropdown<T> extends StatefulWidget {
  const UiDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.placeholder = '请选择',
    this.label,
    this.enabled = true,
    this.maxPopupHeight = 280,
  });

  final List<UiDropdownItem<T>> items;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String placeholder;
  final String? label;
  final bool enabled;
  final double maxPopupHeight;

  @override
  State<UiDropdown<T>> createState() => _UiDropdownState<T>();
}

class _UiDropdownState<T> extends State<UiDropdown<T>> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlay;
  bool get _open => _overlay != null;

  @override
  void dispose() {
    _overlay?.remove();
    _overlay = null;
    super.dispose();
  }

  void _toggle() {
    if (_open) {
      _close();
    } else {
      _show();
    }
  }

  void _close() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() {});
  }

  void _show() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    _overlay = OverlayEntry(
      builder: (ctx) {
        final colors = ctx.uiColors;
        final typography = ctx.uiType;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
              ),
            ),
            Positioned(
              width: size.width,
              child: CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                offset: Offset(0, size.height + 6),
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: widget.maxPopupHeight,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: UiRadius.brMd,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: UiRadius.brMd,
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: widget.items.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 0.6,
                            thickness: 0.6,
                            color: colors.separator,
                          ),
                          itemBuilder: (context, i) {
                            final item = widget.items[i];
                            final selected = item.value == widget.value;
                            return InkWell(
                              onTap: () {
                                widget.onChanged?.call(item.value);
                                _close();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: UiSpacing.lg,
                                    vertical: UiSpacing.md),
                                child: Row(
                                  children: [
                                    if (item.icon != null) ...[
                                      Icon(item.icon,
                                          size: 18,
                                          color: selected
                                              ? colors.brand
                                              : colors.textSecondary),
                                      const SizedBox(width: UiSpacing.sm),
                                    ],
                                    Expanded(
                                      child: Text(
                                        item.label,
                                        style: typography.body.copyWith(
                                          color: selected
                                              ? colors.brand
                                              : colors.textPrimary,
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (selected)
                                      UiIcon(UiIcons.check,
                                          size: 16, color: colors.brand),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context, rootOverlay: true).insert(_overlay!);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final selected = widget.items.firstWhere(
      (e) => e.value == widget.value,
      orElse: () => UiDropdownItem<T>(
        value: widget.value as T,
        label: '',
      ),
    );
    final display = widget.value == null || selected.label.isEmpty
        ? widget.placeholder
        : selected.label;

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
        CompositedTransformTarget(
          link: _link,
          child: GestureDetector(
            onTap: widget.enabled ? _toggle : null,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: UiDuration.fast,
              padding: const EdgeInsets.symmetric(
                  horizontal: UiSpacing.md, vertical: UiSpacing.md),
              decoration: BoxDecoration(
                color: colors.groupedBackground,
                borderRadius: UiRadius.brMd,
                border: Border.all(
                    color: _open ? colors.brand : Colors.transparent,
                    width: 1.2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      display,
                      style: typography.body.copyWith(
                        color: widget.value == null
                            ? colors.textTertiary
                            : colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: UiDuration.base,
                    curve: UiCurves.standard,
                    child: UiIcon(UiIcons.chevronDown,
                        size: 18, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

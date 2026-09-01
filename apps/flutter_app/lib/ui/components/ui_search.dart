import 'package:flutter/material.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
import 'ui_icon.dart';

/// iOS 风格搜索框（SearchBar）。胶囊化、内嵌 "Cancel" 按钮（可选）。
class UiSearch extends StatefulWidget {
  const UiSearch({
    super.key,
    this.controller,
    this.placeholder = '搜索',
    this.onChanged,
    this.onSubmitted,
    this.onCancel,
    this.showCancelButton = true,
    this.autofocus = false,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onCancel;
  final bool showCancelButton;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<UiSearch> createState() => _UiSearchState();
}

class _UiSearchState extends State<UiSearch>
    with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focus;
  bool _showCancel = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focus = widget.focusNode ?? FocusNode();
    _focus.addListener(_onFocus);
    _controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _controller.removeListener(_onTextChange);
    if (widget.focusNode == null) _focus.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onFocus() {
    setState(() => _showCancel = _focus.hasFocus || _controller.text.isNotEmpty);
  }

  void _onTextChange() {
    setState(() {});
  }

  void _handleClear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  void _handleCancel() {
    _controller.clear();
    _focus.unfocus();
    setState(() => _showCancel = false);
    widget.onCancel?.call();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;

    final field = AnimatedContainer(
      duration: UiDuration.base,
      curve: UiCurves.standard,
      padding: const EdgeInsets.symmetric(
          horizontal: UiSpacing.md, vertical: UiSpacing.sm),
      decoration: BoxDecoration(
        color: colors.groupedBackground,
        borderRadius: UiRadius.brMd,
      ),
      child: Row(
        children: [
          UiIcon(UiIcons.search, size: 18, color: colors.textSecondary),
          const SizedBox(width: UiSpacing.sm),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              cursorColor: colors.brand,
              cursorWidth: 1.6,
              style: typography.body.copyWith(color: colors.textPrimary),
              decoration: InputDecoration.collapsed(
                hintText: widget.placeholder,
                hintStyle:
                    typography.body.copyWith(color: colors.textTertiary),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty) ...[
            const SizedBox(width: UiSpacing.xs),
            GestureDetector(
              onTap: _handleClear,
              behavior: HitTestBehavior.opaque,
              child: Icon(Icons.cancel,
                  size: 18, color: colors.textTertiary),
            ),
          ],
        ],
      ),
    );

    if (!widget.showCancelButton) return field;

    return Row(
      children: [
        Expanded(child: field),
        AnimatedSize(
          duration: UiDuration.base,
          curve: UiCurves.standard,
          alignment: Alignment.centerLeft,
          child: _showCancel
              ? Padding(
                  padding: const EdgeInsets.only(left: UiSpacing.sm),
                  child: TextButton(
                    onPressed: _handleCancel,
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: UiSpacing.sm),
                      minimumSize: const Size(0, 36),
                      foregroundColor: colors.brand,
                    ),
                    child: Text(
                      '取消',
                      style: typography.callout.copyWith(color: colors.brand),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

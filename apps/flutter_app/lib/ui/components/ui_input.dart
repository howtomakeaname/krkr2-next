import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// 通用输入框。
///
/// 支持标签、前后图标、辅助文本、错误文本、字符计数，
/// 默认风格为 iOS18 填充胶囊（圆角 14），支持深色模式。
class UiInput extends StatefulWidget {
  const UiInput({
    super.key,
    this.controller,
    this.label,
    this.placeholder,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.autofocus = false,
    this.focusNode,
    this.onTap,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController? controller;
  final String? label;
  final String? placeholder;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final FocusNode? focusNode;
  final VoidCallback? onTap;
  final TextAlign textAlign;

  @override
  State<UiInput> createState() => _UiInputState();
}

class _UiInputState extends State<UiInput> {
  late FocusNode _focus;
  bool get _hasError => widget.errorText != null && widget.errorText!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusNode ?? FocusNode();
    _focus.addListener(_handleFocus);
  }

  @override
  void didUpdateWidget(covariant UiInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _focus.removeListener(_handleFocus);
      _focus = widget.focusNode ?? FocusNode();
      _focus.addListener(_handleFocus);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_handleFocus);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _handleFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final focused = _focus.hasFocus;

    final borderColor = _hasError
        ? colors.danger
        : focused
            ? colors.brand
            : Colors.transparent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: typography.footnote.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: UiSpacing.xs),
        ],
        AnimatedContainer(
          duration: UiDuration.fast,
          curve: UiCurves.standard,
          padding: const EdgeInsets.symmetric(
              horizontal: UiSpacing.md, vertical: UiSpacing.sm),
          decoration: BoxDecoration(
            color: widget.enabled
                ? colors.groupedBackground
                : colors.groupedBackground.withValues(alpha: 0.6),
            borderRadius: UiRadius.brMd,
            border: Border.all(color: borderColor, width: focused ? 1.4 : 1),
          ),
          child: Row(
            crossAxisAlignment: widget.maxLines == 1
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              if (widget.prefixIcon != null) ...[
                Icon(widget.prefixIcon,
                    size: 18, color: colors.textSecondary),
                const SizedBox(width: UiSpacing.sm),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  readOnly: widget.readOnly,
                  onTap: widget.onTap,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  obscureText: widget.obscureText,
                  maxLines: widget.maxLines,
                  minLines: widget.minLines,
                  maxLength: widget.maxLength,
                  autofocus: widget.autofocus,
                  textAlign: widget.textAlign,
                  inputFormatters: widget.inputFormatters,
                  cursorColor: colors.brand,
                  cursorWidth: 1.6,
                  cursorRadius: const Radius.circular(2),
                  style: typography.body.copyWith(color: colors.textPrimary),
                  decoration: InputDecoration.collapsed(
                    hintText: widget.placeholder,
                    hintStyle:
                        typography.body.copyWith(color: colors.textTertiary),
                  ).copyWith(counterText: ''),
                ),
              ),
              if (widget.suffix != null) ...[
                const SizedBox(width: UiSpacing.sm),
                widget.suffix!,
              ] else if (widget.suffixIcon != null) ...[
                const SizedBox(width: UiSpacing.sm),
                Icon(widget.suffixIcon,
                    size: 18, color: colors.textSecondary),
              ],
            ],
          ),
        ),
        if (_hasError || widget.helperText != null) ...[
          const SizedBox(height: UiSpacing.xs),
          Text(
            _hasError ? widget.errorText! : widget.helperText!,
            style: typography.caption.copyWith(
              color: _hasError ? colors.danger : colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

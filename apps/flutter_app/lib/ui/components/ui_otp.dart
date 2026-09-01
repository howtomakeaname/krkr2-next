import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ui_colors.dart';
import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';
import '../theme/ui_typography.dart';

/// 分格验证码输入框（OTP / PIN）。
///
/// - 支持 4~8 位，默认 6 位；
/// - 单个 `TextField` + 遮罩层的实现思路，避免多个输入框来回切换焦点导致
///   的系统键盘/粘贴行为异常（iOS SMS Autofill 推荐做法）；
/// - 支持数字 / 字母数字 / 自定义正则；
/// - 填满后自动触发 [onCompleted]；
/// - 聚焦格子带描边脉动动画；
/// - 支持密码掩码 `obscure`。
class UiOtp extends StatefulWidget {
  const UiOtp({
    super.key,
    this.length = 6,
    this.value,
    this.onChanged,
    this.onCompleted,
    this.autofocus = true,
    this.obscure = false,
    this.enabled = true,
    this.cellSize,
    this.spacing = 10,
    this.inputType = UiOtpInputType.digits,
    this.customFormatter,
    this.errorText,
  })  : assert(length >= 4 && length <= 8, 'OTP 长度建议在 4-8 之间');

  final int length;

  /// 受控值；不传则使用内部状态。
  final String? value;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  final bool autofocus;
  final bool obscure;
  final bool enabled;

  /// 单格尺寸；不设时由可用宽度平均分配。
  final double? cellSize;

  final double spacing;

  final UiOtpInputType inputType;

  /// 当 [inputType] 为 [UiOtpInputType.custom] 时用于过滤输入。
  final TextInputFormatter? customFormatter;

  /// 非空时整体描边变红并显示提示。
  final String? errorText;

  @override
  State<UiOtp> createState() => _UiOtpState();
}

enum UiOtpInputType { digits, alphanumeric, custom }

class _UiOtpState extends State<UiOtp> with SingleTickerProviderStateMixin {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value ?? '');
  late final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(covariant UiOtp old) {
    super.didUpdateWidget(old);
    if (widget.value != null && widget.value != _controller.text) {
      _controller.text = widget.value!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  TextInputFormatter? get _formatter {
    switch (widget.inputType) {
      case UiOtpInputType.digits:
        return FilteringTextInputFormatter.digitsOnly;
      case UiOtpInputType.alphanumeric:
        return FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]'));
      case UiOtpInputType.custom:
        return widget.customFormatter;
    }
  }

  TextInputType get _keyboard => widget.inputType == UiOtpInputType.digits
      ? TextInputType.number
      : TextInputType.text;

  void _handleChanged(String raw) {
    final trimmed =
        raw.length > widget.length ? raw.substring(0, widget.length) : raw;
    if (trimmed != raw) {
      _controller.value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    }
    widget.onChanged?.call(trimmed);
    if (trimmed.length == widget.length) {
      widget.onCompleted?.call(trimmed);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: widget.enabled ? () => _focus.requestFocus() : null,
          child: Stack(
            children: [
              // 真正接收输入的 TextField，透明放在最底层。
              Opacity(
                opacity: 0.01,
                child: SizedBox(
                  height: widget.cellSize ?? 52,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    autofocus: widget.autofocus,
                    enabled: widget.enabled,
                    keyboardType: _keyboard,
                    textInputAction: TextInputAction.done,
                    obscureText: widget.obscure,
                    maxLength: widget.length,
                    showCursor: false,
                    enableInteractiveSelection: false,
                    onChanged: _handleChanged,
                    inputFormatters:
                        _formatter == null ? null : [_formatter!],
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                    ),
                    autofillHints:
                        widget.inputType == UiOtpInputType.digits
                            ? const [AutofillHints.oneTimeCode]
                            : null,
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final totalSpacing = widget.spacing * (widget.length - 1);
                  final maxCell = constraints.hasBoundedWidth
                      ? (constraints.maxWidth - totalSpacing) / widget.length
                      : 52.0;
                  final cell = widget.cellSize ?? maxCell.clamp(36.0, 64.0);

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < widget.length; i++) ...[
                        if (i > 0) SizedBox(width: widget.spacing),
                        _Cell(
                          size: cell,
                          ch: i < _controller.text.length
                              ? _controller.text[i]
                              : null,
                          active:
                              _focus.hasFocus && i == _controller.text.length,
                          hasError: hasError,
                          obscure: widget.obscure,
                          enabled: widget.enabled,
                          typography: typography,
                          colors: colors,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: UiSpacing.xs),
            child: Text(
              widget.errorText!,
              style: typography.footnote.copyWith(color: colors.danger),
            ),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.size,
    required this.ch,
    required this.active,
    required this.hasError,
    required this.obscure,
    required this.enabled,
    required this.typography,
    required this.colors,
  });

  final double size;
  final String? ch;
  final bool active;
  final bool hasError;
  final bool obscure;
  final bool enabled;
  final UiTypography typography;
  final UiColors colors;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? colors.danger
        : active
            ? colors.brand
            : colors.border;
    final bg = !enabled
        ? colors.groupedBackground
        : active
            ? colors.brandMuted.withValues(alpha: 0.6)
            : colors.surface;

    return AnimatedContainer(
      duration: UiDuration.fast,
      curve: UiCurves.standard,
      width: size,
      height: size,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: UiRadius.brMd,
          border: Border.all(
            color: borderColor,
            width: active || hasError ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: UiDuration.fast,
          transitionBuilder: (c, a) =>
              ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
          child: ch == null
              ? (active
                  ? _Caret(color: colors.brand, key: const ValueKey('caret'))
                  : const SizedBox.shrink(key: ValueKey('empty')))
              : Text(
                  obscure ? '•' : ch!,
                  key: ValueKey('v$ch$obscure'),
                  style: typography.title2.copyWith(
                    color: colors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
      ),
    );
  }
}

class _Caret extends StatefulWidget {
  const _Caret({super.key, required this.color});
  final Color color;

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.25, end: 1).animate(_ctrl),
      child: Container(
        width: 2,
        height: 22,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

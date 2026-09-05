import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../theme/ui_colors.dart';
import '../theme/ui_metrics.dart';
import '../theme/ui_springs.dart';
import '../theme/ui_theme.dart';
import 'ui_glass.dart';

/// 按钮视觉变体。
enum UiButtonVariant {
  /// 强调按钮：填充品牌色，用于主操作。
  primary,

  /// 次级按钮：淡蓝背景，文字为品牌色。
  secondary,

  /// 描边按钮：透明背景 + 细边框。
  outline,

  /// 纯文字按钮：无背景无边框。
  ghost,

  /// 危险操作按钮：填充红色。
  danger,
}

/// 按钮尺寸规格。
enum UiButtonSize {
  small,
  medium,

  /// 页面标题栏按钮：44pt 点击区、22pt 图标。
  navigation,
  large,
}

/// iOS18 风格通用按钮。
///
/// 特性：
/// - 按压回弹动画（scale + 透明度），无水波纹；
/// - 支持左右图标、加载态、禁用态；
/// - 支持 `fullWidth` 及自定义最小宽度；
/// - 自动根据 [UiButtonVariant] 解析前景/背景色，并与主题联动。
class UiButton extends StatefulWidget {
  const UiButton({
    super.key,
    required this.label,
    this.onPressed,
    this.onLongPress,
    this.variant = UiButtonVariant.primary,
    this.size = UiButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.fullWidth = false,
    this.minWidth,
    this.enableHaptic = true,
    this.semanticLabel,
  });

  /// 快捷构造：图标按钮（方形），常用于工具栏。
  const UiButton.icon({
    super.key,
    required IconData icon,
    this.onPressed,
    this.onLongPress,
    this.variant = UiButtonVariant.ghost,
    this.size = UiButtonSize.medium,
    this.loading = false,
    this.enableHaptic = true,
    this.semanticLabel,
  }) : label = '',
       leadingIcon = icon,
       trailingIcon = null,
       fullWidth = false,
       minWidth = null;

  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final UiButtonVariant variant;
  final UiButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool loading;
  final bool fullWidth;
  final double? minWidth;
  final bool enableHaptic;
  final String? semanticLabel;

  bool get _iconOnly => label.isEmpty && leadingIcon != null;

  @override
  State<UiButton> createState() => _UiButtonState();
}

class _UiButtonState extends State<UiButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
  );

  bool get _enabled => widget.onPressed != null && !widget.loading;

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  void _animateTo(double target) {
    if (_reduceMotion) {
      _controller.value = target;
      return;
    }
    _controller.animateWith(
      SpringSimulation(
        UiSprings.press,
        _controller.value,
        target,
        _controller.velocity,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (!_enabled) return;
    _animateTo(1);
  }

  void _handleTapCancel() => _animateTo(0);

  void _handleTapUp(TapUpDetails _) => _animateTo(0);

  void _handleTap() {
    if (!_enabled) return;
    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final resolved = _resolveStyle(colors);

    final padding = _resolvePadding();
    final height = _resolveHeight();
    final textStyle = typography.button.copyWith(
      color: resolved.foreground,
      fontSize: _resolveFontSize(),
    );

    final Widget content = widget.loading
        ? SizedBox(
            height: height * 0.5,
            width: height * 0.5,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(resolved.foreground),
            ),
          )
        : _buildContent(textStyle, resolved.foreground);

    final double? minWidth = widget.fullWidth
        ? double.infinity
        : widget.minWidth ?? (widget._iconOnly ? height : null);

    final button = AnimatedContainer(
      duration: UiDuration.fast,
      curve: UiCurves.standard,
      constraints: BoxConstraints(minHeight: height, minWidth: minWidth ?? 0),
      padding: widget._iconOnly ? EdgeInsets.zero : padding,
      decoration: BoxDecoration(
        color: _enabled
            ? resolved.background
            : resolved.background.withValues(alpha: 0.5),
        border: resolved.border,
        borderRadius: BorderRadius.all(
          widget._iconOnly ? UiRadius.md : _resolveRadius(),
        ),
      ),
      // heightFactor 必须显式置 1：Center 默认会撑满有界松约束（如
      // Scaffold 的 FAB 槽位给出的全屏约束），把按钮拉成整屏大。
      child: Center(
        widthFactor: widget.fullWidth ? null : 1,
        heightFactor: 1,
        child: content,
      ),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label:
          widget.semanticLabel ?? (widget.label.isEmpty ? null : widget.label),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapCancel: _handleTapCancel,
        onTapUp: _handleTapUp,
        onTap: _enabled ? _handleTap : null,
        onLongPress: _enabled ? widget.onLongPress : null,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = _controller.value.clamp(0.0, 1.0);
            return Opacity(
              opacity: _enabled ? 1 - (0.06 * progress) : 0.6,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(
                  1 - (0.025 * progress),
                  1 - (0.055 * progress),
                  1,
                ),
                child: child,
              ),
            );
          },
          child: button,
        ),
      ),
    );
  }

  Widget _buildContent(TextStyle textStyle, Color foreground) {
    final iconSize = _resolveIconSize();
    if (widget._iconOnly) {
      return Icon(widget.leadingIcon, size: iconSize, color: foreground);
    }
    final children = <Widget>[];
    if (widget.leadingIcon != null) {
      children.add(Icon(widget.leadingIcon, size: iconSize, color: foreground));
      children.add(const SizedBox(width: UiSpacing.sm));
    }
    children.add(
      Flexible(
        child: Text(
          widget.label,
          style: textStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    if (widget.trailingIcon != null) {
      children.add(const SizedBox(width: UiSpacing.sm));
      children.add(
        Icon(widget.trailingIcon, size: iconSize, color: foreground),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  _ResolvedStyle _resolveStyle(UiColors colors) {
    switch (widget.variant) {
      case UiButtonVariant.primary:
        return _ResolvedStyle(
          background: colors.brand,
          foreground: colors.textOnBrand,
        );
      case UiButtonVariant.secondary:
        return _ResolvedStyle(
          background: colors.brandSoft,
          foreground: colors.brand,
        );
      case UiButtonVariant.outline:
        return _ResolvedStyle(
          background: Colors.transparent,
          foreground: colors.brand,
          border: Border.all(color: colors.brand, width: 1),
        );
      case UiButtonVariant.ghost:
        return _ResolvedStyle(
          background: Colors.transparent,
          foreground: colors.brand,
        );
      case UiButtonVariant.danger:
        return _ResolvedStyle(
          background: colors.danger,
          foreground: colors.textOnBrand,
        );
    }
  }

  EdgeInsets _resolvePadding() {
    switch (widget.size) {
      case UiButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: UiSpacing.md,
          vertical: UiSpacing.xs,
        );
      case UiButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: UiSpacing.lg,
          vertical: UiSpacing.sm,
        );
      case UiButtonSize.navigation:
        return const EdgeInsets.symmetric(horizontal: UiSpacing.md);
      case UiButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: UiSpacing.xl,
          vertical: UiSpacing.md,
        );
    }
  }

  double _resolveHeight() {
    switch (widget.size) {
      case UiButtonSize.small:
        return 32;
      case UiButtonSize.medium:
        return 40;
      case UiButtonSize.navigation:
        return UiNavigationMetrics.buttonExtent;
      case UiButtonSize.large:
        return 50;
    }
  }

  double _resolveIconSize() {
    switch (widget.size) {
      case UiButtonSize.small:
        return 16;
      case UiButtonSize.medium:
        return 18;
      case UiButtonSize.navigation:
        return UiNavigationMetrics.iconSize;
      case UiButtonSize.large:
        return 20;
    }
  }

  double _resolveFontSize() {
    switch (widget.size) {
      case UiButtonSize.small:
        return 14;
      case UiButtonSize.medium:
        return 15;
      case UiButtonSize.navigation:
        return 15;
      case UiButtonSize.large:
        return 17;
    }
  }

  Radius _resolveRadius() {
    switch (widget.size) {
      case UiButtonSize.small:
        return UiRadius.sm;
      case UiButtonSize.medium:
        return UiRadius.md;
      case UiButtonSize.navigation:
        return UiRadius.md;
      case UiButtonSize.large:
        return UiRadius.lg;
    }
  }
}

/// 页面标题栏专用图标按钮。
///
/// 使用 iOS 导航栏的 44pt 有效点击区与 22pt 图标。外层 [Align] 在
/// [AppBar.leading] 的 56pt 槽位中只居中、不放大点击区；放进普通 [Row]
/// 时则保持紧凑的 44pt 尺寸。
class UiBarIconButton extends StatelessWidget {
  const UiBarIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.variant = UiButtonVariant.ghost,
    this.loading = false,
    this.contained = true,
    this.enableBlur,
  });

  static const double extent = UiNavigationMetrics.buttonExtent;
  static const double iconSize = UiNavigationMetrics.iconSize;

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final UiButtonVariant variant;
  final bool loading;
  final bool contained;
  final bool? enableBlur;

  @override
  Widget build(BuildContext context) {
    return Align(
      widthFactor: 1,
      heightFactor: 1,
      child: UiGlassIconButton(
        icon: icon,
        semanticLabel: semanticLabel,
        size: extent,
        iconSize: iconSize,
        contained: contained,
        enableBlur: enableBlur,
        loading: loading,
        foregroundColor: switch (variant) {
          UiButtonVariant.danger => context.uiColors.danger,
          _ => context.uiColors.brand,
        },
        tint: switch (variant) {
          UiButtonVariant.danger => context.uiColors.danger,
          _ => null,
        },
        onPressed: onPressed,
      ),
    );
  }
}

class _ResolvedStyle {
  _ResolvedStyle({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final BoxBorder? border;
}

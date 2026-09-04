import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_springs.dart';
import '../theme/ui_theme.dart';
import 'ui_glass.dart';

/// iOS18 风格操作按钮定义。
class UiDialogAction {
  const UiDialogAction({
    required this.label,
    this.onPressed,
    this.isDestructive = false,
    this.isDefault = false,
    this.returnValue,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;
  final bool isDefault;

  /// 点击该按钮时 [UiDialog.show] 返回的值（静态值场景，如确认框的
  /// true/false）。动态值（如输入框内容）请在 [onPressed] 里自行
  /// `Navigator.pop(context, value)`——按钮会检测到并跳过自动关闭。
  final Object? returnValue;
}

/// iOS 原生 AlertDialog 风格弹窗：圆角卡片 + 垂直/水平按钮栏。
///
/// 使用：
/// ```dart
/// UiDialog.show(
///   context,
///   title: '删除会话',
///   message: '此操作将删除全部消息且无法恢复。',
///   actions: [
///     UiDialogAction(label: '取消'),
///     UiDialogAction(label: '删除', isDestructive: true, onPressed: () {}),
///   ],
/// );
/// ```
class UiDialog {
  UiDialog._();

  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    String? message,
    Widget? content,
    List<UiDialogAction> actions = const [],
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'UiDialog',
      barrierColor: context.uiColors.overlay,
      transitionDuration: UiSprings.materializeDuration,
      pageBuilder: (ctx, a, b) {
        return _DialogView(
          title: title,
          message: message,
          content: content,
          actions: actions,
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: UiSprings.materializeCurve,
          reverseCurve: UiSprings.dismissCurve,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

class _DialogView extends StatelessWidget {
  const _DialogView({
    this.title,
    this.message,
    this.content,
    this.actions = const [],
  });

  final String? title;
  final String? message;
  final Widget? content;
  final List<UiDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;

    final vertical = actions.length > 2;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: UiSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Material(
            color: Colors.transparent,
            child: UiGlassSurface(
              variant: UiGlassVariant.regular,
              borderRadius: UiRadius.brXl,
              enableBlur: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      UiSpacing.xl,
                      UiSpacing.xl,
                      UiSpacing.xl,
                      UiSpacing.lg,
                    ),
                    child: Column(
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            textAlign: TextAlign.center,
                            style: typography.headline.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        if (title != null &&
                            (message != null || content != null))
                          const SizedBox(height: UiSpacing.sm),
                        if (message != null)
                          Text(
                            message!,
                            textAlign: TextAlign.center,
                            style: typography.subheadline.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ?content,
                      ],
                    ),
                  ),
                  if (actions.isNotEmpty)
                    Divider(
                      height: 0.6,
                      thickness: 0.6,
                      color: colors.separator,
                    ),
                  if (actions.isNotEmpty)
                    vertical
                        ? _buildVertical(context, colors)
                        : _buildHorizontal(context, colors),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontal(BuildContext context, colors) {
    final btns = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      btns.add(
        Expanded(
          child: _ActionButton(action: actions[i], colors: colors),
        ),
      );
      if (i != actions.length - 1) {
        btns.add(
          VerticalDivider(width: 0.6, thickness: 0.6, color: colors.separator),
        );
      }
    }
    return IntrinsicHeight(child: Row(children: btns));
  }

  Widget _buildVertical(BuildContext context, colors) {
    final children = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      children.add(_ActionButton(action: actions[i], colors: colors));
      if (i != actions.length - 1) {
        children.add(
          Divider(height: 0.6, thickness: 0.6, color: colors.separator),
        );
      }
    }
    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({required this.action, required this.colors});

  final UiDialogAction action;
  final dynamic colors;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  void _animateTo(double target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _press.value = target;
      return;
    }
    _press.animateWith(
      SpringSimulation(UiSprings.press, _press.value, target, _press.velocity),
    );
  }

  void _select() {
    HapticFeedback.lightImpact();
    widget.action.onPressed?.call();
    // onPressed 里自行 Navigator.pop(context, value) 关闭过弹窗时，
    // 路由已不是栈顶，跳过自动关闭，避免双重 pop 弹出下层页面。
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    Navigator.of(context).pop(widget.action.returnValue);
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.uiType;
    final action = widget.action;
    final colors = widget.colors;
    final tint = action.isDestructive ? colors.danger : colors.brand;
    return Semantics(
      button: true,
      label: action.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _animateTo(1),
        onTapCancel: () => _animateTo(0),
        onTapUp: (_) => _animateTo(0),
        onTap: _select,
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, child) {
            final progress = _press.value.clamp(0.0, 1.0);
            return ColoredBox(
              color: colors.textPrimary.withValues(alpha: 0.08 * progress),
              child: Transform.scale(
                scale: 1 - (0.025 * progress),
                child: child,
              ),
            );
          },
          child: SizedBox(
            height: 48,
            child: Center(
              child: Text(
                action.label,
                style: typography.body.copyWith(
                  color: tint,
                  fontWeight: action.isDefault
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

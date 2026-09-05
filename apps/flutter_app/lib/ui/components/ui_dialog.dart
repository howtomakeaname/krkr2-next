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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Navigator.of(context, rootNavigator: true).push<T>(
      _UiDialogRoute<T>(
        pageBuilder: (ctx, a, b) {
          return _DialogView(
            title: title,
            message: message,
            content: content,
            actions: actions,
          );
        },
        barrierDismissible: barrierDismissible,
        barrierLabel: 'UiDialog',
        barrierColor: Colors.black.withValues(alpha: isDark ? 0.42 : 0.26),
      ),
    );
  }
}

class _UiDialogRoute<T> extends RawDialogRoute<T> {
  _UiDialogRoute({
    required super.pageBuilder,
    required super.barrierDismissible,
    required super.barrierLabel,
    required super.barrierColor,
  }) : super(
         transitionDuration: UiDuration.slow,
         transitionBuilder: (ctx, anim, _, child) {
           return _DialogTransition(animation: anim, child: child);
         },
       );

  @override
  Duration get reverseTransitionDuration => UiSprings.dismissDuration;
}

/// Keeps the expensive backdrop sample out of the moving part of the route.
/// The tint, edge and shadow still materialize during the transition; the real
/// background sample is attached once the dialog has reached its resting size.
class _DialogTransition extends AnimatedWidget {
  const _DialogTransition({required this.animation, required this.child})
    : super(listenable: animation);

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final isDismissing = animation.status == AnimationStatus.reverse;
    final motionCurve = isDismissing
        ? UiSprings.dismissCurve
        : UiSprings.materializeCurve;
    final opacityCurve = isDismissing
        ? UiCurves.iosSmooth
        : UiCurves.iosStandard;
    final motion = reduceMotion
        ? 1.0
        : motionCurve.transform(animation.value).clamp(0.0, 1.08);
    final opacityProgress = reduceMotion
        ? 1.0
        : opacityCurve.transform(animation.value).clamp(0.0, 1.0);
    final opacity = isDismissing
        ? opacityProgress
        : 0.78 + (0.22 * opacityProgress);
    final sampleBackdrop =
        reduceMotion || animation.status == AnimationStatus.completed;

    return _DialogMaterialState(
      sampleBackdrop: sampleBackdrop,
      child: Opacity(
        key: const ValueKey<String>('ui-dialog-motion-opacity'),
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - motion)),
          child: Transform.scale(scale: 0.975 + (0.025 * motion), child: child),
        ),
      ),
    );
  }
}

class _DialogMaterialState extends InheritedWidget {
  const _DialogMaterialState({
    required this.sampleBackdrop,
    required super.child,
  });

  final bool sampleBackdrop;

  static bool sampleBackdropOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_DialogMaterialState>()
          ?.sampleBackdrop ??
      true;

  @override
  bool updateShouldNotify(_DialogMaterialState oldWidget) =>
      sampleBackdrop != oldWidget.sampleBackdrop;
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
    final sampleBackdrop = _DialogMaterialState.sampleBackdropOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final vertical = actions.length > 2;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: UiSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Material(
            color: Colors.transparent,
            child: UiGlassSurface(
              key: const ValueKey<String>('ui-dialog-surface'),
              variant: UiGlassVariant.regular,
              borderRadius: UiRadius.brXl,
              tint: colors.surfaceElevated,
              enableBlur: sampleBackdrop,
              blurScale: 0.12,
              showRefraction: sampleBackdrop,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: isDark ? 0.60 : 0.58),
                ),
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
    // onTapUp has already started the release spring. Keep the selected action
    // visually pressed while the route exits instead of animating it against
    // the dialog's dismiss direction.
    _press.stop();
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

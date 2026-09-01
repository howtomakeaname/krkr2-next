import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_theme.dart';

/// 长按菜单项。
class UiMenuItem {
  const UiMenuItem({
    required this.label,
    this.icon,
    this.onSelected,
    this.isDestructive = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onSelected;
  final bool isDestructive;
}

/// iOS18 风格长按菜单（Context Menu）。
///
/// 模拟 iOS 长按卡片的 "突出 + 菜单浮现" 效果：
/// - 长按子元素后，背景模糊，子元素放大浮起；
/// - 菜单在子元素旁以圆角卡片形式展示；
/// - 点击菜单项或空白处关闭。
class UiContextMenu extends StatefulWidget {
  const UiContextMenu({
    super.key,
    required this.child,
    required this.items,
    this.onTap,
    this.enableHaptic = true,
  });

  final Widget child;
  final List<UiMenuItem> items;
  final VoidCallback? onTap;
  final bool enableHaptic;

  @override
  State<UiContextMenu> createState() => _UiContextMenuState();
}

class _UiContextMenuState extends State<UiContextMenu> {
  final GlobalKey _anchorKey = GlobalKey();

  Future<void> _open() async {
    if (widget.enableHaptic) HapticFeedback.mediumImpact();
    final renderBox =
        _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final mqSize = MediaQuery.sizeOf(context);

    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.32),
        transitionDuration: UiDuration.base,
        reverseTransitionDuration: UiDuration.fast,
        pageBuilder: (ctx, anim, secondary) => _ContextMenuOverlay(
          anchorOffset: offset,
          anchorSize: size,
          screenSize: mqSize,
          items: widget.items,
          animation: anim,
          child: widget.child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _anchorKey,
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.items.isEmpty ? null : _open,
      // 桌面端（macOS/Windows/Linux）鼠标右键同样唤出菜单。
      onSecondaryTap: widget.items.isEmpty ? null : _open,
      child: widget.child,
    );
  }
}

class _ContextMenuOverlay extends StatelessWidget {
  const _ContextMenuOverlay({
    required this.anchorOffset,
    required this.anchorSize,
    required this.screenSize,
    required this.items,
    required this.child,
    required this.animation,
  });

  final Offset anchorOffset;
  final Size anchorSize;
  final Size screenSize;
  final List<UiMenuItem> items;
  final Widget child;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    const menuWidth = 240.0;
    const gap = UiSpacing.sm;

    // 菜单位置：优先出现在锚点下方，若超出底部则放到上方。
    final double estimatedMenuHeight = items.length * 48 + 16;
    final bool placeBelow =
        (anchorOffset.dy + anchorSize.height + gap + estimatedMenuHeight) <
        screenSize.height - 32;

    final double menuTop = placeBelow
        ? anchorOffset.dy + anchorSize.height + gap
        : (anchorOffset.dy - gap - estimatedMenuHeight).clamp(
            24.0,
            double.infinity,
          );

    double menuLeft = anchorOffset.dx;
    if (menuLeft + menuWidth > screenSize.width - 16) {
      menuLeft = screenSize.width - menuWidth - 16;
    }
    menuLeft = menuLeft.clamp(16.0, double.infinity);

    final curved = CurvedAnimation(
      parent: animation,
      curve: UiCurves.emphasized,
    );

    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Positioned(
            left: anchorOffset.dx,
            top: anchorOffset.dy,
            child: IgnorePointer(
              child: ScaleTransition(
                scale: Tween<double>(begin: 1, end: 1.04).animate(curved),
                alignment: Alignment.center,
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: anchorSize.width,
                    height: anchorSize.height,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: menuLeft,
            top: menuTop,
            width: menuWidth,
            child: FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
                alignment: placeBelow
                    ? Alignment.topLeft
                    : Alignment.bottomLeft,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: UiRadius.brMd,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.24),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          if (i != 0)
                            Divider(
                              height: 0.6,
                              thickness: 0.6,
                              color: colors.separator,
                            ),
                          _MenuRow(
                            item: items[i],
                            colors: colors,
                            typography: typography,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.item,
    required this.colors,
    required this.typography,
  });

  final UiMenuItem item;
  final dynamic colors;
  final dynamic typography;

  @override
  Widget build(BuildContext context) {
    final tint = item.isDestructive ? colors.danger : colors.textPrimary;
    return InkWell(
      onTap: () {
        Navigator.of(context).maybePop();
        item.onSelected?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: UiSpacing.lg,
          vertical: UiSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.label,
                style: typography.body.copyWith(color: tint),
              ),
            ),
            if (item.icon != null) Icon(item.icon, size: 18, color: tint),
          ],
        ),
      ),
    );
  }
}

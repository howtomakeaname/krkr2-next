import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ui_metrics.dart';
import '../theme/ui_springs.dart';
import '../theme/ui_theme.dart';
import 'ui_glass.dart';
import 'ui_icon.dart';

const double _menuVerticalPadding = 4;
const double _menuDividerExtent = 0.5;
const double _menuWidth = 250;

double _menuItemExtent(BuildContext context, UiMenuItem item) {
  if (item.subtitle == null || item.subtitle!.isEmpty) return 44;

  var textWidth = _menuWidth - UiSpacing.lg * 2;
  if (item.selected) textWidth -= 16 + UiSpacing.sm;
  if (item.icon != null) textWidth -= 20 + UiSpacing.sm;

  final typography = context.uiType;
  final textDirection = Directionality.of(context);
  final textScaler = MediaQuery.textScalerOf(context);
  final locale = Localizations.maybeLocaleOf(context);

  double textHeight(String text, TextStyle style, int maxLines) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: textWidth);
    return painter.height;
  }

  final labelHeight = textHeight(
    item.label,
    typography.body.copyWith(fontSize: 17, height: 1.25),
    1,
  );
  final subtitleHeight = textHeight(item.subtitle!, typography.caption, 2);
  return math.max(
    44,
    (UiSpacing.sm * 2 + labelHeight + subtitleHeight).ceilToDouble(),
  );
}

/// 菜单项。长按 [UiContextMenu] 与点按 [UiPopupMenu] 共用。
class UiMenuItem {
  const UiMenuItem({
    required this.label,
    this.subtitle,
    this.icon,
    this.onSelected,
    this.isDestructive = false,
    this.selected = false,
    this.value,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onSelected;
  final bool isDestructive;
  final bool selected;

  /// [UiPopupMenu.show] 选中后作为返回值。
  final Object? value;
}

/// 点按处弹出的 iOS 18 风格菜单（UIMenu / pull-down）。
///
/// 与 [UiContextMenu] 共用同一块毛玻璃菜单；区别是由点按触发、不抬起源视图。
class UiPopupMenu {
  UiPopupMenu._();

  static Rect? rectOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  static Future<T?> show<T>(
    BuildContext context, {
    required List<UiMenuItem> items,
    Rect? anchor,
    bool alignEnd = true,
  }) {
    final resolved = anchor ?? rectOf(context);
    if (resolved == null || items.isEmpty) {
      return Future<T?>.value();
    }
    return Navigator.of(context, rootNavigator: true).push<T>(
      PageRouteBuilder<T>(
        opaque: false,
        // iOS UIMenu 不铺一层模态压暗，否则浮层会像对话框。
        barrierColor: Colors.transparent,
        barrierDismissible: true,
        barrierLabel: 'Dismiss',
        transitionDuration: UiDuration.slow,
        reverseTransitionDuration: UiDuration.fast,
        pageBuilder: (ctx, anim, secondary) {
          return _PopupMenuPage(
            anchor: resolved,
            items: items,
            animation: anim,
            alignEnd: alignEnd,
          );
        },
      ),
    );
  }
}

/// iOS18 风格长按菜单（Context Menu）。
///
/// 长按后源视图轻微放大，菜单在旁边以毛玻璃卡片弹出。
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
    if (renderBox == null || !renderBox.hasSize) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final colors = context.uiColors;
    final isLight = Theme.of(context).brightness == Brightness.light;

    await Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: colors.overlay.withValues(alpha: isLight ? 0.18 : 0.30),
        transitionDuration: UiDuration.slow,
        reverseTransitionDuration: UiDuration.fast,
        pageBuilder: (ctx, anim, secondary) => _ContextMenuOverlay(
          anchorOffset: offset,
          anchorSize: size,
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
      onSecondaryTap: widget.items.isEmpty ? null : _open,
      child: widget.child,
    );
  }
}

class _PopupMenuPage extends StatelessWidget {
  const _PopupMenuPage({
    required this.anchor,
    required this.items,
    required this.animation,
    required this.alignEnd,
  });

  final Rect anchor;
  final List<UiMenuItem> items;
  final Animation<double> animation;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        _AnchoredMenu(
          anchor: anchor,
          items: items,
          animation: animation,
          alignEnd: alignEnd,
          liftChild: false,
        ),
      ],
    );
  }
}

class _ContextMenuOverlay extends StatelessWidget {
  const _ContextMenuOverlay({
    required this.anchorOffset,
    required this.anchorSize,
    required this.items,
    required this.child,
    required this.animation,
  });

  final Offset anchorOffset;
  final Size anchorSize;
  final List<UiMenuItem> items;
  final Widget child;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: _AnchoredMenu(
        anchor: anchorOffset & anchorSize,
        items: items,
        animation: animation,
        // Context menus choose the edge nearest the screen side so a menu
        // opened from a right-hand card grows back toward that card.
        alignEnd: null,
        liftChild: true,
        lifted: child,
      ),
    );
  }
}

class _AnchoredMenu extends StatefulWidget {
  const _AnchoredMenu({
    required this.anchor,
    required this.items,
    required this.animation,
    required this.alignEnd,
    required this.liftChild,
    this.lifted,
  });

  final Rect anchor;
  final List<UiMenuItem> items;
  final Animation<double> animation;

  /// Whether to align the menu's right edge with the anchor's right edge.
  /// `null` selects the nearest horizontal screen edge automatically.
  final bool? alignEnd;
  final bool liftChild;
  final Widget? lifted;

  @override
  State<_AnchoredMenu> createState() => _AnchoredMenuState();
}

class _AnchoredMenuState extends State<_AnchoredMenu> {
  late CurvedAnimation _curved;

  @override
  void initState() {
    super.initState();
    _curved = _newCurved();
  }

  @override
  void didUpdateWidget(covariant _AnchoredMenu old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation) {
      _curved.dispose();
      _curved = _newCurved();
    }
  }

  CurvedAnimation _newCurved() => CurvedAnimation(
    parent: widget.animation,
    curve: UiSprings.materializeCurve,
    reverseCurve: UiSprings.dismissCurve,
  );

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anchor = widget.anchor;
    final items = widget.items;
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final curved = _curved;
    final alignEnd = widget.alignEnd ?? (anchor.center.dx >= size.width / 2);

    final itemExtents = [
      for (final item in items) _menuItemExtent(context, item),
    ];
    var estimatedHeight = _menuVerticalPadding * 2;
    for (final extent in itemExtents) {
      estimatedHeight += extent;
    }
    estimatedHeight +=
        math.max(0, items.length - 1) * _menuDividerExtent;

    final minTop = padding.top + 8;
    final maxBottom = size.height - padding.bottom - 8;
    final placeBelow =
        (anchor.bottom + 6 + estimatedHeight) <= maxBottom ||
        anchor.top - 6 - estimatedHeight < minTop;
    final menuTop = placeBelow
        ? (anchor.bottom + 6).clamp(minTop, maxBottom - estimatedHeight)
        : (anchor.top - 6 - estimatedHeight).clamp(minTop, double.infinity);

    double menuLeft;
    if (alignEnd) {
      menuLeft = anchor.right - _menuWidth;
    } else {
      menuLeft = anchor.left;
    }
    menuLeft = menuLeft.clamp(16.0, size.width - _menuWidth - 16);

    return Stack(
      children: [
        if (widget.liftChild && widget.lifted != null)
          Positioned(
            left: anchor.left,
            top: anchor.top,
            child: IgnorePointer(
              child: ScaleTransition(
                scale: Tween<double>(begin: 1, end: 1.04).animate(curved),
                alignment: Alignment.center,
                child: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    width: anchor.width,
                    height: anchor.height,
                    child: widget.lifted,
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: curved,
            builder: (context, _) {
              final geometryProgress = curved.value.clamp(0.0, 1.012);
              final visibility = curved.value.clamp(0.0, 1.0);
              final finalRect = Rect.fromLTWH(
                menuLeft,
                menuTop,
                _menuWidth,
                estimatedHeight,
              );
              // Menus grow from a compact lens at the source's actionable
              // edge. Keeping this seed to one touch target also prevents a
              // full-width settings row from turning into a giant slab.
              final seedWidth = math.min(44.0, anchor.width);
              final seedHeight = math.min(44.0, anchor.height);
              final seedLeft = alignEnd
                  ? anchor.right - seedWidth
                  : anchor.left;
              final seedTop = placeBelow
                  ? anchor.bottom - seedHeight / 2
                  : anchor.top - seedHeight / 2;
              final seedRect = Rect.fromLTWH(
                seedLeft,
                seedTop,
                seedWidth,
                seedHeight,
              );
              final materialRect = Rect.lerp(
                seedRect,
                finalRect,
                geometryProgress,
              )!;
              final contentOpacity = const Interval(
                0.18,
                0.56,
                curve: Curves.easeOutCubic,
              ).transform(visibility);
              final radius = _GlassMenuMaterial.radius +
                  (seedHeight / 2 - _GlassMenuMaterial.radius) *
                      (1 - visibility);

              return Stack(
                children: [
                  Positioned.fromRect(
                    rect: materialRect,
                    child: _GlassMenuMaterial(
                      key: const ValueKey<String>('ui-popup-menu-material'),
                      borderRadius: radius,
                    ),
                  ),
                  Positioned.fill(
                    child: ClipPath(
                      clipper: _MenuRevealClipper(
                        rect: materialRect,
                        radius: radius,
                      ),
                      child: Stack(
                        children: [
                          Positioned.fromRect(
                            rect: finalRect,
                            child: IgnorePointer(
                              ignoring: visibility < 0.98,
                              child: Opacity(
                                opacity: contentOpacity,
                                child: _GlassMenuContent(
                                  items: items,
                                  itemExtents: itemExtents,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GlassMenuMaterial extends StatelessWidget {
  const _GlassMenuMaterial({
    super.key,
    required this.borderRadius,
  });

  final double borderRadius;
  static const double radius = 22;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: UiGlassSurface(
      variant: UiGlassVariant.regular,
      borderRadius: BorderRadius.circular(borderRadius),
      enableBlur: true,
      child: const SizedBox.expand(),
    ),
  );
}

class _GlassMenuContent extends StatelessWidget {
  const _GlassMenuContent({
    required this.items,
    required this.itemExtents,
  });

  final List<UiMenuItem> items;
  final List<double> itemExtents;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _menuVerticalPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i != 0)
                Divider(
                  height: _menuDividerExtent,
                  thickness: _menuDividerExtent,
                  color: colors.separator,
                ),
              SizedBox(
                height: itemExtents[i],
                child: _MenuRow(
                  item: items[i],
                  isFirst: i == 0,
                  isLast: i == items.length - 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuRevealClipper extends CustomClipper<Path> {
  const _MenuRevealClipper({required this.rect, required this.radius});

  final Rect rect;
  final double radius;

  @override
  Path getClip(Size size) => Path()
    ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

  @override
  bool shouldReclip(covariant _MenuRevealClipper oldClipper) =>
      rect != oldClipper.rect || radius != oldClipper.radius;
}

class _MenuRow extends StatefulWidget {
  const _MenuRow({
    required this.item,
    required this.isFirst,
    required this.isLast,
  });

  final UiMenuItem item;
  final bool isFirst;
  final bool isLast;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _pressed = false;
  bool _hovered = false;
  bool _selecting = false;
  // 弹出动画期间指针会“撞进”第一行；进场结束前不点亮。
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(UiDuration.slow, () {
      if (mounted) setState(() => _armed = true);
    });
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  Future<void> _select() async {
    if (_selecting) return;
    _selecting = true;

    final item = widget.item;
    final onSelected = item.onSelected;
    final route = ModalRoute.of(context);
    final nav = Navigator.of(context);
    nav.pop(item.value);

    // Context-menu actions often open another route (confirmation dialogs,
    // metadata scraping, and so on). Wait until this overlay has completed
    // its reverse transition before invoking the action; pushing immediately
    // leaves the old menu underneath the new route and it can resurface after
    // the source card is rebuilt or removed.
    if (route != null) await route.completed;
    onSelected?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final typography = context.uiType;
    final item = widget.item;
    final tint = item.isDestructive ? colors.danger : colors.textPrimary;
    final Color wash;
    if (_pressed) {
      wash = colors.textPrimary.withValues(alpha: 0.08);
    } else if (_hovered) {
      wash = colors.textPrimary.withValues(alpha: 0.04);
    } else {
      wash = Colors.transparent;
    }
    final radius = Radius.circular(_GlassMenuMaterial.radius - 1);
    final BorderRadius? corners = widget.isFirst && widget.isLast
        ? BorderRadius.all(radius)
        : widget.isFirst
        ? BorderRadius.vertical(top: radius)
        : widget.isLast
        ? BorderRadius.vertical(bottom: radius)
        : null;

    return MouseRegion(
      onHover: (_) {
        if (!_armed) return;
        _setHovered(true);
      },
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: _select,
        child: AnimatedContainer(
          duration: UiDuration.fast,
          curve: UiCurves.iosSmooth,
          decoration: BoxDecoration(color: wash, borderRadius: corners),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: UiSpacing.lg,
            vertical: UiSpacing.sm,
          ),
          child: Row(
            children: [
              if (item.selected) ...[
                UiIcon(UiIcons.check, size: 16, color: colors.brand),
                const SizedBox(width: UiSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      style: typography.body.copyWith(
                        color: tint,
                        fontSize: 17,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.subtitle != null && item.subtitle!.isNotEmpty)
                      Text(
                        item.subtitle!,
                        style: typography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (item.icon != null) ...[
                const SizedBox(width: UiSpacing.sm),
                Icon(item.icon, size: 20, color: tint),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart' show CupertinoTheme, CupertinoThemeData;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'ui_badge.dart';

class UiNavItem {
  const UiNavItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.badgeCount,
    this.badgeDot = false,
  });

  final IconData icon;
  final String label;
  final IconData? activeIcon;
  final int? badgeCount;
  final bool badgeDot;
}

/// App navigation adapter. Glass optics and touch physics belong to
/// liquid_glass_widgets; this layer owns destinations and accessibility.
class UiNavBar extends StatelessWidget {
  const UiNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onChanged,
    this.backgroundColor,
    this.showLabel = true,
    this.enableHaptic = true,
  }) : assert(items.length >= 2),
       assert(currentIndex >= 0 && currentIndex < items.length);

  final List<UiNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  /// Legacy name: overrides the selected icon/label accent, not the glass fill.
  final Color? backgroundColor;
  final bool showLabel;
  final bool enableHaptic;

  void _select(int index) {
    if (index == currentIndex) return;
    if (enableHaptic) HapticFeedback.selectionClick();
    onChanged(index);
  }

  Widget _icon(UiNavItem item, {bool active = false}) => UiBadge(
    count: item.badgeCount,
    dot: item.badgeDot,
    child: Icon(active ? item.activeIcon ?? item.icon : item.icon),
  );

  @override
  Widget build(BuildContext context) {
    final height = showLabel ? 64.0 : 52.0;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: GlassAccessibilityScope(
            // The sampler initializes from MediaQuery, while glass resolves
            // Cupertino colors. Seed both from the app's explicit ThemeMode;
            // the package can then adapt them together to the content below.
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Theme.of(context).brightness,
              ),
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(platformBrightness: Theme.of(context).brightness),
                child: SizedBox(
                  key: const ValueKey('ui-nav-glass'),
                  height: height,
                  child: Stack(
                    // The pressed indicator expands outside the resting capsule.
                    clipBehavior: Clip.none,
                    children: [
                      ExcludeFocus(
                        child: ExcludeSemantics(
                          child: GlassTabBar.bottom(
                            tabs: [
                              for (final item in items)
                                GlassTab(
                                  icon: _icon(item),
                                  activeIcon: _icon(item, active: true),
                                  label: showLabel ? item.label : null,
                                  semanticLabel: item.label,
                                ),
                            ],
                            selectedIndex: currentIndex,
                            onTabSelected: _select,
                            horizontalPadding: 0,
                            verticalPadding: 0,
                            barHeight: height,
                            adaptiveBrightness: true,
                            quality: GlassQuality.premium,
                            // Null keeps the library's content-aware black/white
                            // labels, including when artwork changes appearance.
                            selectedIconColor: backgroundColor,
                            selectedLabelColor: backgroundColor,
                            selectedLabelStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                            interactionBehavior: reduceMotion
                                ? GlassInteractionBehavior.none
                                : GlassInteractionBehavior.full,
                          ),
                        ),
                      ),
                      // 1.4.0 delegates touch to the draggable indicator, but its
                      // visual tab rows have no semantic activation callbacks.
                      // Supply accessible destinations without intercepting drags.
                      Positioned.fill(
                        child: Row(
                          children: [
                            for (var index = 0; index < items.length; index++)
                              Expanded(
                                child: Actions(
                                  actions: {
                                    ActivateIntent:
                                        CallbackAction<ActivateIntent>(
                                          onInvoke: (_) {
                                            _select(index);
                                            return null;
                                          },
                                        ),
                                  },
                                  child: Focus(
                                    child: Semantics(
                                      key: ValueKey('ui-nav-item-$index'),
                                      container: true,
                                      button: true,
                                      selected: index == currentIndex,
                                      label: items[index].label,
                                      onTap: () => _select(index),
                                      child: const IgnorePointer(
                                        child: SizedBox.expand(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

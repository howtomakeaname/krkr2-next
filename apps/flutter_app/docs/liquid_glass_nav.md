# Bottom navigation

`UiNavBar` adapts `liquid_glass_widgets` 1.4.0's `GlassTabBar.bottom`.
Package source: https://github.com/sdegenaar/liquid_glass_widgets

## Rendering

- Flutter 3.41 or newer is required. `main()` preloads the package shaders.
- The bar requests `GlassQuality.premium`. The package uses Impeller shader
  filters when supported and falls back on other renderers. Requesting premium
  does **not** prove that a device is rendering premium glass.
- HarmonyOS already enables Impeller in `ohos/entry/src/main/resources/rawfile/buildinfo.json5`.
- The bar uses package material, refraction and drag/press springs. Do not add
  a second blurred surface, dark media overlay or custom painted rim around it.
- Labels use the package's adaptive black/white appearance. Selected state also
  uses the moving glass indicator, filled icon and stronger label weight.
- The adapter seeds its local MediaQuery and Cupertino appearance from the app
  theme. Otherwise 1.4.0 initializes labels from the OS theme and can paint black
  labels on a dark bar when the app and system appearance differ.
- `GlassContentAwareScope` samples the home content during scrolling, with no
  idle ticker. Home rebuilds request an additional sample for tab/data changes.
  It captures only the body, not the navigation bar or route overlays.

## Layout and input

- 64-point bar; 20-point side insets; maximum width 400; system bottom safe area
  with an 8-point minimum. The parent does not clip the pressed indicator.
- Keep the existing `Scaffold` and `IndexedStack`: import, search, scroll-state
  retention and menu transitions do not need a second navigation shell.
- Version 1.4.0's visual tab rows have no activation callbacks. The adapter
  provides one semantic action and keyboard focus target per destination.
  This layer must not consume pointer events; the package owns tapping/dragging.
- Reduced-motion preferences reach the package springs through
  `GlassAccessibilityScope`; the bar's press scale/glow is also disabled.

## Verification

```sh
flutter test test/ui_nav_bar_test.dart test/home_tabs_test.dart \
  test/widget_test.dart test/home_page_context_menu_test.dart test/ui_glass_test.dart
flutter build hap --release --no-pub
```

Widget tests cover layout, input and navigation, not GPU optical fidelity.
On a connected device, check light/dark themes over both cover art and plain
pages; tap all destinations, drag across the bar, reverse a drag and release
outside it. Verify label contrast, edge refraction, unclipped spring recovery,
safe-area placement, and that import/search/context menus remain unchanged.
Check shader-load errors and frame timings during the same interaction.
The startup log `[NavigationGlass] shader filters supported: ...` reports the
renderer capability; also inspect shader initialization errors before treating
the premium path as available.

The unsigned HarmonyOS package is in
`ohos/entry/build/default/outputs/default/entry-default-unsigned.hap`.
A successful unsigned build does not update any older signed HAP in
`build/ohos/hap/`; sign the new output before installing it.

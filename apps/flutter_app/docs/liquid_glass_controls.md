# Glass controls

`UiGlassIconButton` adapts `liquid_glass_widgets` 1.4.0's
`GlassButton.custom`. `UiBarIconButton` continues to use that adapter.
Ordinary `UiButton` variants and the existing menu transitions are unchanged.

## Material and interaction

- Standalone controls request premium glass. The package selects the supported
  renderer; widget tests do not verify GPU refraction.
- `UiGlassToolbar` owns one glass capsule. Its `contained: false` children use
  transparent buttons, without another glass surface or a second press scale.
- `UiGlassToolbar.custom` accepts the search editor as its body. Setting
  `interactive: false` keeps the lens still during text editing, without
  replacing the editor or changing its width animation.
- Press scale is 1.06 for standalone buttons and 1.025 for the shared toolbar.
  The library's default +17pt growth makes a 44pt button exceed the existing
  56pt app bar. Keep both the press growth and directional stretch within that
  space; do not fix clipping by removing the glass effect.
- The package owns anchored stretching and spring recovery. Press illumination
  is limited to 4% in dark appearance and 8% in light appearance.
- Icons keep the app accent or an explicit foreground color. A local Cupertino
  theme makes the glass follow the app appearance, even if the OS differs.

## Input and accessibility

- Keep the existing 44pt navigation hit target. Disabled/loading controls do
  not receive pointer events; entering either state cancels an active press.
- The adapter provides one labeled semantic action, optional long press and
  haptic feedback. Keyboard activation uses the package focus implementation.
- Reduced motion disables press scaling and directional stretching. Explicit
  `enableBlur: false` uses the shader-free, unblurred fallback.

## Verification

```sh
flutter test test/ui_glass_test.dart test/ui_bar_icon_button_test.dart \
  test/home_tabs_test.dart test/home_page_context_menu_test.dart
```

On device, hold and drag a return button near the app bar edges, then cancel.
Check that its outline stays intact. Repeat import-menu open/dismiss and search
expand/collapse; verify the library does not move and the editor retains focus.
Check both plain pages and a detail page with cover art behind the toolbar.

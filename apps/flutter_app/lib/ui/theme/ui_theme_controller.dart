import 'package:flutter/material.dart';

import 'ui_colors.dart';

/// 主题运行时控制器。
///
/// 业务层持有一个全局 [UiThemeController]，可以在任何位置调用
/// [updateSeed] / [toggleMode] 动态切换主题色和亮暗模式，
/// 所有订阅该通知者的组件会自动重建。
///
/// 与 `Provider` 无关，保持零依赖：基于 [ChangeNotifier]。
class UiThemeController extends ChangeNotifier {
  UiThemeController({
    Color seed = UiSeedPalette.teal,
    ThemeMode mode = ThemeMode.system,
  })  : _seed = seed,
        _mode = mode;

  Color _seed;
  ThemeMode _mode;

  Color get seed => _seed;
  ThemeMode get mode => _mode;

  void updateSeed(Color seed) {
    if (seed == _seed) return;
    _seed = seed;
    notifyListeners();
  }

  void updateMode(ThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }

  void toggleMode() {
    updateMode(_mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

/// InheritedWidget 形式暴露 [UiThemeController]，组件内通过
/// `UiThemeScope.of(context)` 访问。
class UiThemeScope extends InheritedNotifier<UiThemeController> {
  const UiThemeScope({
    super.key,
    required UiThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static UiThemeController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<UiThemeScope>();
    assert(scope != null, 'UiThemeScope 未挂载，请在顶层 MaterialApp 之上包裹');
    return scope!.notifier!;
  }
}

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_theme_mode.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../constants/prefs_keys.dart';
import '../services/app_theme_platform.dart';
import '../ui/ui.dart';
import 'home_page.dart';

/// Standalone settings page with MD3 styling and i18n support.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.engineMode,
    required this.customDylibPath,
    required this.builtInDylibPath,
    required this.builtInAvailable,
    required this.perfOverlay,
    required this.fpsLimitEnabled,
    required this.targetFps,
    required this.renderer,
    required this.angleBackend,
    required this.gameOrientation,
    this.restartPending = false,
    this.publicGamesDir,
  });

  final EngineMode engineMode;
  final String? customDylibPath;
  final String? builtInDylibPath;
  final bool builtInAvailable;
  final bool perfOverlay;
  final bool fpsLimitEnabled;
  final int targetFps;
  final String renderer;
  final String angleBackend;
  final String gameOrientation;
  final bool restartPending;

  /// OHOS: user-facing label of the public drop folder
  /// (`Download/<bundleName>/games`). Null on platforms without one.
  final String? publicGamesDir;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

/// Return value from the settings page.
class SettingsResult {
  const SettingsResult({
    required this.engineMode,
    required this.customDylibPath,
    required this.perfOverlay,
    required this.fpsLimitEnabled,
    required this.targetFps,
    required this.renderer,
    required this.angleBackend,
    required this.gameOrientation,
    this.restartPending = false,
  });

  final EngineMode engineMode;
  final String? customDylibPath;
  final bool perfOverlay;
  final bool fpsLimitEnabled;
  final int targetFps;
  final String renderer;
  final String angleBackend;
  final String gameOrientation;

  /// 已写入需重启才能生效的项，用户选择了稍后手动重启。
  final bool restartPending;
}

/// 退出当前进程。系统桌面会留下图标，用户点一下即相当于冷启动。
Future<void> restartKrkr2App() async {
  await WidgetsBinding.instance.endOfFrame;
  exit(0);
}

class _SettingsPageState extends State<SettingsPage> {
  late EngineMode _engineMode;
  late String? _customDylibPath;
  late bool _perfOverlay;
  late bool _fpsLimitEnabled;
  late int _targetFps;
  late String _renderer;
  String _angleBackend = PrefsKeys.angleBackendGles;
  late String _gameOrientation;
  String _localeCode = 'system';
  String _themeModeCode = AppThemeMode.defaultCode;
  bool _restartDeferred = false;

  @override
  void initState() {
    super.initState();
    _engineMode = widget.engineMode;
    _customDylibPath = widget.customDylibPath;
    _perfOverlay = widget.perfOverlay;
    _fpsLimitEnabled = widget.fpsLimitEnabled;
    _targetFps = widget.targetFps;
    _renderer = widget.renderer;
    _angleBackend = widget.angleBackend;
    _gameOrientation = widget.gameOrientation;
    _restartDeferred = widget.restartPending;
    _loadLocale();
    _loadThemeMode();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _localeCode = prefs.getString(PrefsKeys.locale) ?? 'system';
      });
    }
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _themeModeCode = AppThemeMode.normalize(
          prefs.getString(PrefsKeys.themeMode),
        );
      });
    }
  }

  SettingsResult _result() => SettingsResult(
    engineMode: _engineMode,
    customDylibPath: _customDylibPath,
    perfOverlay: _perfOverlay,
    fpsLimitEnabled: _fpsLimitEnabled,
    targetFps: _targetFps,
    renderer: _renderer,
    angleBackend: _angleBackend,
    gameOrientation: _gameOrientation,
    restartPending: _restartDeferred,
  );

  void _pop() {
    Navigator.pop(context, _result());
  }

  Future<void> _writePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PrefsKeys.engineMode,
      _engineMode == EngineMode.custom
          ? PrefsKeys.engineModeCustom
          : PrefsKeys.engineModeBuiltIn,
    );
    if (_customDylibPath != null) {
      await prefs.setString(PrefsKeys.dylibPath, _customDylibPath!);
    } else {
      await prefs.remove(PrefsKeys.dylibPath);
    }
    await prefs.setBool(PrefsKeys.perfOverlay, _perfOverlay);
    await prefs.setBool(PrefsKeys.fpsLimitEnabled, _fpsLimitEnabled);
    await prefs.setInt(PrefsKeys.targetFps, _targetFps);
    await prefs.setString(PrefsKeys.renderer, _renderer);
    await prefs.setString(PrefsKeys.angleBackend, _angleBackend);
    await prefs.setString(PrefsKeys.gameOrientation, _gameOrientation);
    await prefs.setBool(
      PrefsKeys.forceLandscape,
      _gameOrientation == PrefsKeys.gameOrientationLandscape,
    );
  }

  Future<void> _commitLive(VoidCallback apply) async {
    setState(apply);
    await _writePrefs();
  }

  /// 改完即写后询问是否立刻重启；取消则留下可手动重启的提示。
  Future<void> _commitNeedsRestart(VoidCallback apply) async {
    setState(apply);
    await _writePrefs();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final restartNow = await UiDialog.show<bool>(
      context,
      title: l10n.restartRequiredTitle,
      message: l10n.restartRequiredMessage,
      barrierDismissible: false,
      actions: [
        UiDialogAction(label: l10n.cancel, returnValue: false),
        UiDialogAction(
          label: l10n.applyAndRestart,
          isDefault: true,
          returnValue: true,
        ),
      ],
    );
    if (!mounted) return;
    if (restartNow == true) {
      await restartKrkr2App();
      if (mounted) setState(() => _restartDeferred = true);
      return;
    }
    setState(() => _restartDeferred = true);
  }

  /// iOS 设置惯例：点按取值行，在该行旁弹出带 checkmark 的菜单。
  Future<T?> _showValuePicker<T>({
    required Rect anchor,
    required T current,
    required List<UiDropdownItem<T>> options,
  }) {
    return UiPopupMenu.show<T>(
      context,
      anchor: anchor,
      items: [
        for (final item in options)
          UiMenuItem(
            label: item.label,
            icon: item.icon,
            selected: item.value == current,
            value: item.value,
          ),
      ],
    );
  }

  String _rendererLabel(String value, AppLocalizations l10n) =>
      value == 'opengl' ? 'OpenGL' : l10n.software;

  String _orientationLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case PrefsKeys.gameOrientationPortrait:
        return l10n.orientationPortrait;
      case PrefsKeys.gameOrientationAuto:
        return l10n.orientationAuto;
      default:
        return l10n.orientationLandscape;
    }
  }

  String _themeLabel(String code, AppLocalizations l10n) {
    return switch (AppThemeMode.normalize(code)) {
      AppThemeMode.system => l10n.themeSystem,
      AppThemeMode.light => l10n.themeLight,
      _ => l10n.themeDark,
    };
  }

  String _localeLabel(String code, AppLocalizations l10n) {
    final map = {
      'system': l10n.languageSystem,
      'en': l10n.languageEn,
      'zh': l10n.languageZh,
      'ja': l10n.languageJa,
    };
    return map[code] ?? code;
  }

  Future<void> _changeLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.locale, code);
    if (!mounted) return;
    setState(() => _localeCode = code);

    // Apply locale change in real-time
    if (code == 'system') {
      Krkr2App.setLocale(context, null);
    } else {
      Krkr2App.setLocale(context, Locale(code));
    }
  }

  Future<void> _changeThemeMode(String code) async {
    final normalized = AppThemeMode.normalize(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.themeMode, normalized);
    if (!mounted) return;
    setState(() => _themeModeCode = normalized);

    await AppThemePlatform.apply(normalized);
    if (!mounted) return;

    // Apply theme change in real-time
    Krkr2App.setThemeMode(context, AppThemeMode.fromCode(normalized));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final colors = context.uiColors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _pop();
      },
      child: Scaffold(
        backgroundColor: colors.groupedBackground,
        appBar: AppBar(
          title: Text(l10n.settings),
          backgroundColor: colors.groupedBackground,
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: UiSpacing.sm),
          children: [
            if (_restartDeferred)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  UiSpacing.lg,
                  UiSpacing.sm,
                  UiSpacing.lg,
                  UiSpacing.md,
                ),
                child: UiBanner(
                  tone: UiBannerTone.warning,
                  message: l10n.restartPendingBanner,
                  actionLabel: l10n.restartNow,
                  onAction: restartKrkr2App,
                ),
              ),
            // ── Engine section (desktop only) ──
            // On Android/iOS the engine is always bundled; no switching needed.
            if (!Platform.isAndroid &&
                !Platform.isIOS &&
                Platform.operatingSystem != 'ohos')
              UiListSection(
                header: l10n.settingsEngine,
                children: [
                  UiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.engineMode, style: context.uiType.title3),
                        const SizedBox(height: UiSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: UiSegmented<EngineMode>(
                            value: _engineMode,
                            items: [
                              UiSegmentedItem(
                                value: EngineMode.builtIn,
                                label: l10n.builtIn,
                                icon: LucideIcons.packageOpen,
                              ),
                              UiSegmentedItem(
                                value: EngineMode.custom,
                                label: l10n.custom,
                                icon: LucideIcons.folderOpen,
                              ),
                            ],
                            onChanged: (value) {
                              if (value == _engineMode) return;
                              _commitNeedsRestart(() => _engineMode = value);
                            },
                          ),
                        ),
                        const SizedBox(height: UiSpacing.md),
                        if (_engineMode == EngineMode.builtIn)
                          _buildBuiltInStatus(context, l10n),
                        if (_engineMode == EngineMode.custom)
                          _buildCustomDylibPicker(context, l10n),
                      ],
                    ),
                  ),
                ],
              ),

            // ── Rendering section ──
            UiListSection(
              header: l10n.settingsRendering,
              footer: l10n.renderPipelineHint,
              children: [
                // 提示文案统一放在分组 footer，tile 不再重复 subtitle。
                UiListTile(
                  title: l10n.renderPipeline,
                  trailingText: _rendererLabel(_renderer, l10n),
                  showChevron: true,
                  onTapRect: (anchor) async {
                    final v = await _showValuePicker<String>(
                      anchor: anchor,
                      current: _renderer,
                      options: [
                        UiDropdownItem(value: 'opengl', label: 'OpenGL'),
                        UiDropdownItem(value: 'software', label: l10n.software),
                      ],
                    );
                    if (v == null || v == _renderer || !mounted) return;
                    await _commitNeedsRestart(() => _renderer = v);
                  },
                ),
                if (Platform.isAndroid)
                  UiListTile(
                    title: l10n.graphicsBackend,
                    subtitle: l10n.graphicsBackendHint,
                    trailingText: _angleBackend == 'gles' ? 'GLES' : 'Vulkan',
                    showChevron: true,
                    onTapRect: (anchor) async {
                      final v = await _showValuePicker<String>(
                        anchor: anchor,
                        current: _angleBackend,
                        options: const [
                          UiDropdownItem(value: 'gles', label: 'GLES'),
                          UiDropdownItem(value: 'vulkan', label: 'Vulkan'),
                        ],
                      );
                      if (v == null || v == _angleBackend || !mounted) return;
                      await _commitNeedsRestart(() => _angleBackend = v);
                    },
                  ),
                UiListTile(
                  title: l10n.performanceOverlay,
                  subtitle: l10n.performanceOverlayDesc,
                  trailing: UiSwitch(
                    value: _perfOverlay,
                    onChanged: (value) =>
                        _commitLive(() => _perfOverlay = value),
                  ),
                ),
                UiListTile(
                  title: l10n.fpsLimitEnabled,
                  subtitle: _fpsLimitEnabled
                      ? l10n.fpsLimitEnabledDesc
                      : l10n.fpsLimitOff,
                  trailing: UiSwitch(
                    value: _fpsLimitEnabled,
                    onChanged: (value) =>
                        _commitLive(() => _fpsLimitEnabled = value),
                  ),
                ),
                if (_fpsLimitEnabled)
                  UiListTile(
                    title: l10n.targetFrameRate,
                    subtitle: l10n.targetFrameRateDesc,
                    trailingText: l10n.fpsLabel(_targetFps),
                    showChevron: true,
                    onTapRect: (anchor) async {
                      final v = await _showValuePicker<int>(
                        anchor: anchor,
                        current: _targetFps,
                        options: PrefsKeys.fpsOptions
                            .map(
                              (fps) => UiDropdownItem(
                                value: fps,
                                label: l10n.fpsLabel(fps),
                              ),
                            )
                            .toList(),
                      );
                      if (v == null || v == _targetFps || !mounted) return;
                      await _commitLive(() => _targetFps = v);
                    },
                  ),
                if (PrefsKeys.orientationSupported)
                  UiListTile(
                    title: l10n.screenOrientation,
                    subtitle: l10n.screenOrientationDesc,
                    trailingText: _orientationLabel(_gameOrientation, l10n),
                    showChevron: true,
                    onTapRect: (anchor) async {
                      final v = await _showValuePicker<String>(
                        anchor: anchor,
                        current: _gameOrientation,
                        options: [
                          UiDropdownItem(
                            value: PrefsKeys.gameOrientationLandscape,
                            label: l10n.orientationLandscape,
                            icon: LucideIcons.rectangleHorizontal,
                          ),
                          UiDropdownItem(
                            value: PrefsKeys.gameOrientationPortrait,
                            label: l10n.orientationPortrait,
                            icon: LucideIcons.rectangleVertical,
                          ),
                          UiDropdownItem(
                            value: PrefsKeys.gameOrientationAuto,
                            label: l10n.orientationAuto,
                            icon: LucideIcons.rotate3d,
                          ),
                        ],
                      );
                      if (v == null || v == _gameOrientation || !mounted) {
                        return;
                      }
                      await _commitLive(() => _gameOrientation = v);
                    },
                  ),
              ],
            ),

            // ── Games section (OHOS: public drop folder) ──
            if (widget.publicGamesDir != null)
              UiListSection(
                header: l10n.settingsGames,
                footer: l10n.publicGamesDirHint(widget.publicGamesDir!),
                children: [
                  UiListTile(
                    icon: LucideIcons.folderOpen,
                    title: l10n.publicGamesDir,
                    subtitle: widget.publicGamesDir,
                    trailing: Icon(
                      LucideIcons.copy,
                      size: 18,
                      color: colors.textTertiary,
                    ),
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: widget.publicGamesDir!),
                      );
                      UiSnackbar.show(
                        context,
                        message: l10n.copiedToClipboard,
                        type: UiSnackbarType.success,
                        duration: const Duration(seconds: 2),
                      );
                    },
                  ),
                ],
              ),

            // ── General section ──
            UiListSection(
              header: l10n.settingsGeneral,
              children: [
                UiListTile(
                  title: l10n.themeMode,
                  trailingText: _themeLabel(_themeModeCode, l10n),
                  showChevron: true,
                  onTapRect: (anchor) async {
                    final v = await _showValuePicker<String>(
                      anchor: anchor,
                      current: _themeModeCode,
                      options: [
                        UiDropdownItem(
                          value: AppThemeMode.system,
                          label: l10n.themeSystem,
                          icon: LucideIcons.monitorCog,
                        ),
                        UiDropdownItem(
                          value: AppThemeMode.light,
                          label: l10n.themeLight,
                          icon: LucideIcons.sun,
                        ),
                        UiDropdownItem(
                          value: AppThemeMode.dark,
                          label: l10n.themeDark,
                          icon: LucideIcons.moon,
                        ),
                      ],
                    );
                    if (v != null) await _changeThemeMode(v);
                  },
                ),
                UiListTile(
                  title: l10n.language,
                  trailingText: _localeLabel(_localeCode, l10n),
                  showChevron: true,
                  onTapRect: (anchor) async {
                    final v = await _showValuePicker<String>(
                      anchor: anchor,
                      current: _localeCode,
                      options: [
                        UiDropdownItem(
                          value: 'system',
                          label: l10n.languageSystem,
                        ),
                        UiDropdownItem(value: 'en', label: l10n.languageEn),
                        UiDropdownItem(value: 'zh', label: l10n.languageZh),
                        UiDropdownItem(value: 'ja', label: l10n.languageJa),
                      ],
                    );
                    if (v != null) await _changeLocale(v);
                  },
                ),
              ],
            ),

            // ── About section ──
            UiListSection(
              header: l10n.settingsAbout,
              children: [
                UiListTile(
                  icon: LucideIcons.flaskConical,
                  title: l10n.version,
                  subtitle: l10n.aboutVersionDesc,
                ),
                UiListTile(
                  icon: LucideIcons.user,
                  title: l10n.aboutAuthor,
                  trailingText: 'reAAAq',
                ),
                UiListTile(
                  icon: LucideIcons.mail,
                  title: l10n.aboutEmail,
                  trailingText: 'wangguanzhiabcd@126.com',
                  onTap: () {
                    Clipboard.setData(
                      const ClipboardData(text: 'wangguanzhiabcd@126.com'),
                    );
                    UiSnackbar.show(
                      context,
                      message: l10n.aboutEmailCopied,
                      type: UiSnackbarType.success,
                      duration: const Duration(seconds: 2),
                    );
                  },
                ),
                UiListTile(
                  icon: LucideIcons.code,
                  title: 'GitHub',
                  subtitle: 'github.com/reAAAq/KrKr2-Next',
                  showChevron: true,
                  onTap: () {
                    launchUrl(
                      Uri.parse('https://github.com/reAAAq/KrKr2-Next'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: UiSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildBuiltInStatus(BuildContext context, AppLocalizations l10n) {
    final colors = context.uiColors;
    final ok = widget.builtInAvailable;
    final tint = ok ? colors.success : colors.danger;
    return Container(
      padding: const EdgeInsets.all(UiSpacing.md),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: UiRadius.brSm,
        border: Border.all(color: tint.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            ok ? LucideIcons.circleCheck : LucideIcons.triangleAlert,
            color: tint,
            size: 20,
          ),
          const SizedBox(width: UiSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok ? l10n.builtInEngineAvailable : l10n.builtInEngineNotFound,
                  style: context.uiType.footnote.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tint,
                  ),
                ),
                if (!ok)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l10n.builtInEngineHint,
                      style: context.uiType.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomDylibPicker(BuildContext context, AppLocalizations l10n) {
    final colors = context.uiColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.engineDylibPath, style: context.uiType.title3),
        const SizedBox(height: UiSpacing.sm),
        Container(
          padding: const EdgeInsets.all(UiSpacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: UiRadius.brSm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _customDylibPath ?? l10n.notSetRequired,
                  style: context.uiType.footnote.copyWith(
                    fontFamily: 'monospace',
                    color: _customDylibPath != null
                        ? colors.textPrimary
                        : colors.danger.withValues(alpha: 0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_customDylibPath != null)
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 18),
                  tooltip: l10n.clearPath,
                  onPressed: () {
                    _commitNeedsRestart(() => _customDylibPath = null);
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: UiSpacing.md),
        SizedBox(
          width: double.infinity,
          child: UiButton(
            label: l10n.browse,
            leadingIcon: LucideIcons.folderOpen,
            variant: UiButtonVariant.outline,
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                dialogTitle: l10n.selectEngineDylib,
                type: FileType.any,
              );
              if (result != null && result.files.single.path != null) {
                final path = result.files.single.path;
                if (path == _customDylibPath) return;
                await _commitNeedsRestart(() => _customDylibPath = path);
              }
            },
          ),
        ),
      ],
    );
  }
}

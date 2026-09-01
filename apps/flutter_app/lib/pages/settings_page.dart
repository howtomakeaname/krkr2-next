import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../main.dart';
import '../constants/prefs_keys.dart';
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
    required this.forceLandscape,
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
  final bool forceLandscape;

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
    required this.forceLandscape,
  });

  final EngineMode engineMode;
  final String? customDylibPath;
  final bool perfOverlay;
  final bool fpsLimitEnabled;
  final int targetFps;
  final String renderer;
  final String angleBackend;
  final bool forceLandscape;
}

class _SettingsPageState extends State<SettingsPage> {
  late EngineMode _engineMode;
  late String? _customDylibPath;
  late bool _perfOverlay;
  late bool _fpsLimitEnabled;
  late int _targetFps;
  late String _renderer;
  String _angleBackend = PrefsKeys.angleBackendGles;
  late bool _forceLandscape;
  String _localeCode = 'system';
  String _themeModeCode = 'dark';
  bool _dirty = false;

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
    _forceLandscape = widget.forceLandscape;
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
        _themeModeCode = prefs.getString(PrefsKeys.themeMode) ?? 'dark';
      });
    }
  }

  Future<void> _save() async {
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
    await prefs.setBool(PrefsKeys.forceLandscape, _forceLandscape);

    if (mounted) {
      Navigator.pop(
        context,
        SettingsResult(
          engineMode: _engineMode,
          customDylibPath: _customDylibPath,
          perfOverlay: _perfOverlay,
          fpsLimitEnabled: _fpsLimitEnabled,
          targetFps: _targetFps,
          renderer: _renderer,
          angleBackend: _angleBackend,
          forceLandscape: _forceLandscape,
        ),
      );
    }
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  /// iOS 设置惯例的取值行：点按后从底部弹出单选列表，返回选中值。
  ///
  /// 选择器（segmented/dropdown）直接塞进 tile 的 trailing 槽在窄屏上
  /// 会被压缩变形，所以值类设置统一走"当前值 + chevron → 底部弹选"。
  Future<T?> _showValuePicker<T>({
    required String title,
    required T current,
    required List<UiDropdownItem<T>> options,
  }) {
    return UiBottomSheet.show<T>(
      context,
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in options)
            UiListTile(
              title: item.label,
              trailing: UiRadio<T>(
                value: item.value,
                groupValue: current,
                onChanged: (v) => Navigator.pop(context, v),
              ),
              onTap: () => Navigator.pop(context, item.value),
            ),
        ],
      ),
    );
  }

  String _rendererLabel(String value, AppLocalizations l10n) =>
      value == 'opengl' ? 'OpenGL' : l10n.software;

  String _themeLabel(String code, AppLocalizations l10n) =>
      code == 'light' ? l10n.themeLight : l10n.themeDark;

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.themeMode, code);
    if (!mounted) return;
    setState(() => _themeModeCode = code);

    // Apply theme change in real-time
    final mode = code == 'light' ? ThemeMode.light : ThemeMode.dark;
    Krkr2App.setThemeMode(context, mode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await UiDialog.show<bool>(
          context,
          title: l10n.settings,
          message: l10n.discardChangesMessage,
          actions: [
            UiDialogAction(label: l10n.cancel, returnValue: false),
            UiDialogAction(
              label: l10n.discard,
              isDestructive: true,
              returnValue: true,
            ),
          ],
        );
        if (discard == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.settings),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: UiSpacing.md),
              child: UiButton(
                label: l10n.save,
                leadingIcon: LucideIcons.save,
                size: UiButtonSize.small,
                onPressed: _dirty ? _save : null,
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: UiSpacing.sm),
          children: [
            // ── Engine section (desktop only) ──
            // On Android/iOS the engine is always bundled; no switching needed.
            if (!Platform.isAndroid && !Platform.isIOS)
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
                              setState(() => _engineMode = value);
                              _markDirty();
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
                  onTap: () async {
                    final v = await _showValuePicker<String>(
                      title: l10n.renderPipeline,
                      current: _renderer,
                      options: [
                        UiDropdownItem(value: 'opengl', label: 'OpenGL'),
                        UiDropdownItem(value: 'software', label: l10n.software),
                      ],
                    );
                    if (v == null || !mounted) return;
                    setState(() => _renderer = v);
                    _markDirty();
                  },
                ),
                if (Platform.isAndroid)
                  UiListTile(
                    title: l10n.graphicsBackend,
                    subtitle: l10n.graphicsBackendHint,
                    trailingText: _angleBackend == 'gles' ? 'GLES' : 'Vulkan',
                    showChevron: true,
                    onTap: () async {
                      final v = await _showValuePicker<String>(
                        title: l10n.graphicsBackend,
                        current: _angleBackend,
                        options: const [
                          UiDropdownItem(value: 'gles', label: 'GLES'),
                          UiDropdownItem(value: 'vulkan', label: 'Vulkan'),
                        ],
                      );
                      if (v == null || !mounted) return;
                      setState(() => _angleBackend = v);
                      _markDirty();
                    },
                  ),
                UiListTile(
                  title: l10n.performanceOverlay,
                  subtitle: l10n.performanceOverlayDesc,
                  trailing: UiSwitch(
                    value: _perfOverlay,
                    onChanged: (value) {
                      setState(() => _perfOverlay = value);
                      _markDirty();
                    },
                  ),
                ),
                UiListTile(
                  title: l10n.fpsLimitEnabled,
                  subtitle: _fpsLimitEnabled
                      ? l10n.fpsLimitEnabledDesc
                      : l10n.fpsLimitOff,
                  trailing: UiSwitch(
                    value: _fpsLimitEnabled,
                    onChanged: (value) {
                      setState(() => _fpsLimitEnabled = value);
                      _markDirty();
                    },
                  ),
                ),
                if (_fpsLimitEnabled)
                  UiListTile(
                    title: l10n.targetFrameRate,
                    subtitle: l10n.targetFrameRateDesc,
                    trailingText: l10n.fpsLabel(_targetFps),
                    showChevron: true,
                    onTap: () async {
                      final v = await _showValuePicker<int>(
                        title: l10n.targetFrameRate,
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
                      if (v == null || !mounted) return;
                      setState(() => _targetFps = v);
                      _markDirty();
                    },
                  ),
                if (Platform.isAndroid || Platform.isIOS)
                  UiListTile(
                    title: l10n.forceLandscape,
                    subtitle: l10n.forceLandscapeDesc,
                    trailing: UiSwitch(
                      value: _forceLandscape,
                      onChanged: (value) {
                        setState(() => _forceLandscape = value);
                        _markDirty();
                      },
                    ),
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
                  onTap: () async {
                    final v = await _showValuePicker<String>(
                      title: l10n.themeMode,
                      current: _themeModeCode,
                      options: [
                        UiDropdownItem(
                          value: 'dark',
                          label: l10n.themeDark,
                          icon: LucideIcons.moon,
                        ),
                        UiDropdownItem(
                          value: 'light',
                          label: l10n.themeLight,
                          icon: LucideIcons.sun,
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
                  onTap: () async {
                    final v = await _showValuePicker<String>(
                      title: l10n.language,
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
                    setState(() => _customDylibPath = null);
                    _markDirty();
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
                setState(() => _customDylibPath = result.files.single.path);
                _markDirty();
              }
            },
          ),
        ),
      ],
    );
  }
}

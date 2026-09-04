import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/game_engine.dart';
import '../models/game_info.dart';
import '../services/game_manager.dart';
import '../ui/ui.dart';
import '../widgets/home_game_card.dart';
import 'game_detail_page.dart';
import 'game_page.dart';
import 'settings_page.dart';
import '../constants/prefs_keys.dart';

/// Engine loading mode: built-in (bundled in .app) or custom (user-specified).
enum EngineMode { builtIn, custom }

/// The home / launcher page — manage and launch games.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final GameManager _gameManager = GameManager();
  bool _loading = true;
  String? _iosGamesDir;
  // OHOS: sandbox path of Download/<bundleName>/games (and its short label
  // for UI copy). Users drop whole game folders here with the file manager.
  String? _ohosGamesDir;
  String? _ohosGamesDirDisplay;
  // On Android/iOS the engine is always built-in; EngineMode switching is
  // only meaningful on desktop platforms.
  EngineMode _engineMode = EngineMode.builtIn;
  String? _customDylibPath;
  String? _builtInDylibPath;
  bool _builtInAvailable = false;
  bool _perfOverlay = false;
  bool _fpsLimitEnabled = false;
  int _targetFps = PrefsKeys.defaultFps;
  String _renderer = PrefsKeys.rendererOpengl;
  String _angleBackend = PrefsKeys.angleBackendGles;
  String _gameOrientation = PrefsKeys.gameOrientationLandscape;
  bool _restartDeferred = false;

  String? _resolveBuiltInDylibPath() {
    if (Platform.isIOS) {
      return '__static_linked__';
    }
    if (Platform.isAndroid) {
      // On Android, native libs are bundled in the APK and loaded
      // automatically via DynamicLibrary.open('libengine_api.so').
      return '__bundled_in_apk__';
    }
    if (Platform.operatingSystem == 'ohos') {
      // Same as Android: libengine_api.so is packaged in the HAP and
      // resolved by the loader search path.
      return '__bundled_in_hap__';
    }
    try {
      final executablePath = Platform.resolvedExecutable;
      final execDir = File(executablePath).parent.path;
      final frameworksPath = '$execDir/../Frameworks/libengine_api.dylib';
      final resolved = File(frameworksPath);
      if (resolved.existsSync()) return resolved.path;
    } catch (_) {}
    return null;
  }

  String? get _effectiveDylibPath {
    if (_engineMode == EngineMode.builtIn) {
      // On iOS/Android/OHOS, the engine is loaded automatically by the system;
      // no explicit dylib path is needed.
      if (Platform.isIOS ||
          Platform.isAndroid ||
          Platform.operatingSystem == 'ohos') {
        return null;
      }
      return _builtInDylibPath;
    }
    return _customDylibPath;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadGames();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the file manager after copying a game in: pick it up
    // without making the user pull to refresh.
    if (state == AppLifecycleState.resumed &&
        Platform.operatingSystem == 'ohos' &&
        !_loading) {
      unawaited(_refreshOhosGames(silent: true));
    }
  }

  Future<void> _loadGames() async {
    final prefs = await SharedPreferences.getInstance();
    _builtInDylibPath = _resolveBuiltInDylibPath();
    _builtInAvailable = _builtInDylibPath != null;
    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile platforms always use the bundled engine; skip mode loading.
      _engineMode = EngineMode.builtIn;
      _customDylibPath = null;
    } else {
      final modeStr = prefs.getString(PrefsKeys.engineMode);
      _engineMode = modeStr == PrefsKeys.engineModeCustom
          ? EngineMode.custom
          : EngineMode.builtIn;
      _customDylibPath = prefs.getString(PrefsKeys.dylibPath);
    }
    _perfOverlay = prefs.getBool(PrefsKeys.perfOverlay) ?? false;
    _fpsLimitEnabled = prefs.getBool(PrefsKeys.fpsLimitEnabled) ?? false;
    _targetFps = prefs.getInt(PrefsKeys.targetFps) ?? PrefsKeys.defaultFps;
    if (!PrefsKeys.fpsOptions.contains(_targetFps))
      _targetFps = PrefsKeys.defaultFps;
    _renderer = prefs.getString(PrefsKeys.renderer) ?? PrefsKeys.rendererOpengl;
    _angleBackend =
        prefs.getString(PrefsKeys.angleBackend) ?? PrefsKeys.angleBackendGles;
    _gameOrientation = PrefsKeys.readGameOrientation(
      prefs.getString(PrefsKeys.gameOrientation),
      legacyForceLandscape: prefs.getBool(PrefsKeys.forceLandscape),
    );
    await _gameManager.load();
    await _gameManager.applyPendingPlaySession();

    if (Platform.isIOS) {
      await _initIosGamesDir();
    } else if (Platform.operatingSystem == 'ohos') {
      await _initOhosGamesDir();
      await _scanOhosGamesDir();
    }

    if (mounted) setState(() => _loading = false);
  }

  /// OHOS: resolve (and on first run create) `Download/<bundleName>/games/`.
  ///
  /// The app owns `Download/<bundleName>/` without any permission prompt;
  /// the native side creates it through a silent DOWNLOAD-mode picker save
  /// and hands back the sandbox path. Failure leaves [_ohosGamesDir] null
  /// and the rest of the import flow (hdc side-load, network) still works.
  Future<void> _initOhosGamesDir() async {
    if (_ohosGamesDir != null) return;
    try {
      final info = await _platformChannel.invokeMapMethod<String, dynamic>(
        'ensurePublicGamesDir',
      );
      final path = info?['path'] as String?;
      if (path == null || path.isEmpty) return;
      _ohosGamesDir = path;
      _ohosGamesDirDisplay = (info?['display'] as String?) ?? path;
    } on PlatformException catch (e) {
      debugPrint('ensurePublicGamesDir failed: ${e.code} ${e.message}');
    } on MissingPluginException {
      // Older native plugin without this method.
    }
  }

  /// OHOS: register games that appeared under [_ohosGamesDir] and drop
  /// entries whose folder the user has since deleted. Returns the number of
  /// newly added games.
  Future<int> _scanOhosGamesDir() async {
    final dirPath = _ohosGamesDir;
    if (dirPath == null) return 0;
    final root = Directory(dirPath);
    if (!root.existsSync()) return 0;

    for (final game in List<GameInfo>.of(_gameManager.games)) {
      if (p.isWithin(dirPath, game.path) &&
          !Directory(game.path).existsSync() &&
          !File(game.path).existsSync()) {
        await _gameManager.removeGame(game.path);
      }
    }

    final candidates = <String>{};
    for (final dir in _scanSandboxForGameDirectories(root)) {
      candidates.add(dir.path);
    }
    for (final file in _scanSandboxForXp3(root)) {
      candidates.add(file.path);
    }
    // A folder is registered as one game; loose archives inside it
    // (data.xp3 + patch.xp3 ...) are part of that game, not separate ones.
    final dirs = candidates.where((c) => Directory(c).existsSync()).toSet();
    candidates.removeWhere(
      (c) => !dirs.contains(c) && dirs.any((d) => p.isWithin(d, c)),
    );

    final registered = _gameManager.games.map((g) => g.path).toSet();
    final fresh = candidates.where((c) => !registered.contains(c)).toList()
      ..sort();
    var added = 0;
    for (final path in fresh) {
      if (await _gameManager.addGame(GameInfo(path: path))) added++;
    }
    return added;
  }

  /// OHOS: rescan the public games folder. [silent] skips the result toast
  /// (lifecycle-triggered scans); pull-to-refresh and the menu report back.
  Future<void> _refreshOhosGames({bool silent = false}) async {
    await _initOhosGamesDir();
    final added = await _scanOhosGamesDir();
    if (!mounted) return;
    if (added > 0 || !silent) setState(() {});
    if (silent) return;
    final l10n = AppLocalizations.of(context)!;
    UiSnackbar.show(
      context,
      message: added > 0 ? l10n.gamesImported(added) : l10n.noNewGamesFound,
      type: added > 0 ? UiSnackbarType.success : UiSnackbarType.info,
    );
  }

  Future<void> _initIosGamesDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final gamesDir = Directory('${docDir.path}/Games');
    if (!await gamesDir.exists()) {
      await gamesDir.create(recursive: true);
    }
    _iosGamesDir = gamesDir.path;
    await _scanIosGamesDir();
  }

  Future<void> _scanIosGamesDir() async {
    if (_iosGamesDir == null) return;
    final gamesDir = Directory(_iosGamesDir!);
    if (!await gamesDir.exists()) return;

    // Remove stale entries whose directories no longer exist on disk
    // (handles iOS sandbox UUID changes leaving orphaned entries).
    final stale = <String>[];
    for (final g in _gameManager.games) {
      if (!await Directory(g.path).exists()) {
        stale.add(g.path);
      }
    }
    for (final path in stale) {
      await _gameManager.removeGame(path);
    }

    final existingByName = <String, GameInfo>{};
    for (final g in _gameManager.games) {
      existingByName[p.basename(g.path)] = g;
    }

    final entries = await gamesDir.list().toList();
    final scannedNames = <String>{};
    for (final entry in entries) {
      if (entry is Directory) {
        final name = p.basename(entry.path);
        scannedNames.add(name);
        final existing = existingByName[name];
        if (existing != null) {
          if (existing.path != entry.path) {
            await _gameManager.updateGamePath(existing.path, entry.path);
          }
        } else {
          final game = GameInfo(path: entry.path);
          await _gameManager.addGame(game);
        }
      }
    }

    final toRemove = _gameManager.games
        .where(
          (g) =>
              g.path.startsWith(_iosGamesDir!) &&
              !scannedNames.contains(p.basename(g.path)),
        )
        .map((g) => g.path)
        .toList();
    for (final path in toRemove) {
      await _gameManager.removeGame(path);
    }
  }

  Rect _fallbackMenuAnchor(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    return Rect.fromLTWH(size.width - 64, pad.top + 8, 44, 44);
  }

  Future<void> _addGame({Rect? anchor}) async {
    final l10n = AppLocalizations.of(context)!;
    if (Platform.isIOS) {
      await _scanIosGamesDir();
      if (mounted) {
        setState(() {});
        _showIosImportGuide();
      }
      return;
    }

    final source = await UiPopupMenu.show<String>(
      context,
      anchor: anchor ?? _fallbackMenuAnchor(context),
      items: [
        UiMenuItem(
          label: l10n.selectGameDirectory,
          icon: LucideIcons.folderOpen,
          value: 'directory',
        ),
        UiMenuItem(
          label: l10n.selectGameArchive,
          icon: LucideIcons.archive,
          value: 'xp3',
        ),
        if (Platform.operatingSystem == 'ohos')
          UiMenuItem(
            label: l10n.rescanGamesDir,
            subtitle: l10n.rescanGamesDirDesc(
              _ohosGamesDirDisplay ?? 'Download/<bundleName>/games',
            ),
            icon: LucideIcons.scanSearch,
            value: 'sandbox',
          ),
      ],
    );
    if (source == null || !mounted) return;

    if (source == 'directory') {
      await _addGameDirectory();
    } else if (source == 'sandbox') {
      await _addGameFromSandbox();
    } else {
      await _addGameArchive();
    }
  }

  Future<void> _addGameDirectory() async {
    final l10n = AppLocalizations.of(context)!;
    if (Platform.operatingSystem == 'ohos') {
      await _addGameDirectoryOhos();
      return;
    }
    final String? selectedDirectory = await FilePicker.platform
        .getDirectoryPath(dialogTitle: l10n.selectGameDirectory);
    if (selectedDirectory == null || !mounted) return;

    final game = GameInfo(path: selectedDirectory);
    final added = await _gameManager.addGame(game);
    if (mounted) {
      if (added) {
        setState(() {});
        _offerScrapeAfterAdd(selectedDirectory);
      } else {
        UiSnackbar.show(
          context,
          message: l10n.gameAlreadyExists(game.displayTitle),
          type: UiSnackbarType.warning,
        );
      }
    }
  }

  static const MethodChannel _platformChannel = MethodChannel(
    'flutter_engine_bridge',
  );

  Future<void> _addGameArchive() async {
    final l10n = AppLocalizations.of(context)!;

    if (Platform.isAndroid) {
      // Native picker: zero-copy, returns real filesystem path directly.
      final realPath = await _platformChannel.invokeMethod<String>('pickFile');
      if (realPath == null || !mounted) return;
      if (!realPath.toLowerCase().endsWith('.xp3')) {
        UiSnackbar.show(
          context,
          message: l10n.selectGameArchive,
          type: UiSnackbarType.warning,
        );
        return;
      }
      final game = GameInfo(path: realPath);
      final added = await _gameManager.addGame(game);
      if (mounted) {
        if (added) {
          setState(() {});
          _offerScrapeAfterAdd(realPath);
        } else {
          UiSnackbar.show(
            context,
            message: l10n.gameAlreadyExists(p.basename(realPath)),
            type: UiSnackbarType.warning,
          );
        }
      }
      return;
    }

    if (Platform.isMacOS) {
      // Using getDirectoryPath() causes macOS to grant powerbox-level access to the entire folder,
      // which persists across app launches and allows the engine to open all files within the directory.
      await _showMacosImportGuide();

      final selectedDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: l10n.selectGameArchive,
      );
      if (selectedDir == null || !mounted) return;

      final xp3Files =
          Directory(selectedDir)
              .listSync()
              .whereType<File>()
              .where((f) => f.path.toLowerCase().endsWith('.xp3'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      if (xp3Files.isEmpty) {
        UiSnackbar.show(
          context,
          message: l10n.selectGameArchive,
          type: UiSnackbarType.warning,
        );
        return;
      }

      // Pick the main XP3 file.
      final File? selectedFile;
      if (xp3Files.length == 1) {
        selectedFile = xp3Files.first;
      } else {
        selectedFile = await _pickXp3File(xp3Files);
        if (selectedFile == null || !mounted) return;
      }

      final game = GameInfo(path: selectedFile.path);
      final added = await _gameManager.addGame(game);
      if (mounted) {
        if (added) {
          setState(() {});
          _offerScrapeAfterAdd(selectedFile.path);
        } else {
          UiSnackbar.show(
            context,
            message: l10n.gameAlreadyExists(p.basename(selectedFile.path)),
            type: UiSnackbarType.warning,
          );
        }
      }
      return;
    }

    if (Platform.operatingSystem == 'ohos') {
      await _addGameArchiveOhos();
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: l10n.selectGameArchive,
      type: FileType.custom,
      allowedExtensions: ['xp3', 'XP3'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final xp3Files = result.files.where((f) {
      final path = f.path;
      if (path == null) return false;
      return path.toLowerCase().endsWith('.xp3');
    }).toList();

    if (xp3Files.isEmpty) {
      if (mounted) {
        UiSnackbar.show(
          context,
          message: l10n.selectGameArchive,
          type: UiSnackbarType.warning,
        );
      }
      return;
    }

    int addedCount = 0;
    String? lastAddedPath;
    for (final file in xp3Files) {
      final filePath = file.path;
      if (filePath == null) continue;
      final game = GameInfo(path: filePath);
      if (await _gameManager.addGame(game)) {
        addedCount++;
        lastAddedPath = filePath;
      }
    }
    if (mounted) {
      if (addedCount > 0) {
        setState(() {});
        if (addedCount == 1 && lastAddedPath != null) {
          _offerScrapeAfterAdd(lastAddedPath);
        }
      } else {
        UiSnackbar.show(
          context,
          message: l10n.gameAlreadyExists(xp3Files.first.name),
          type: UiSnackbarType.warning,
        );
      }
    }
  }

  /// OHOS import path. The system document picker only hands out docs://
  /// URIs, not POSIX paths, so the fopen-based engine can't consume what it
  /// returns — and every app is sandboxed anyway. Games therefore arrive by
  /// side-loading, and importing means scanning the sandbox plus a few
  /// well-known developer roots instead of running a system picker.
  static const List<String> _ohosExtraScanRoots = [
    '/data/local/tmp',
    // Sandbox files root (parent of the documents dir). `hdc file send`
    // can deliver multi-GB archives here at ~400 MB/s — far faster and
    // more reliable than the rport HTTP tunnel — and it stays inside the
    // app sandbox, so the engine can always read it.
    '/data/storage/el2/base/files',
  ];

  /// OHOS 导入：系统 DocumentViewPicker 选 .xp3（可多选）。
  ///
  /// 适配版 file_picker 的实现会把选中文件拷贝到应用 cache
  /// （`cache/file_picker/`）再返回路径；cache 可能被系统清理，所以这里把
  /// 副本改名移入应用 files 目录后再注册（同卷 rename 瞬时完成，失败时
  /// 回退拷贝）。多选让"进入文件夹勾选多个 .xp3"成为文件夹导入的兜底
  /// ——folder 选择模式在部分系统版本上没有确认按钮。
  Future<void> _addGameArchiveOhos() async {
    final l10n = AppLocalizations.of(context)!;
    // .xp3 不是常见后缀，且适配层把无点号扩展名直接传给 OHOS 的
    // fileSuffixFilters（格式不符会过滤失败），因此用 any 选择 + 自行校验。
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(allowMultiple: true);
    } on Exception {
      // 适配层在用户取消时可能抛异常而非返回 null，视同取消。
      result = null;
    }
    if (!mounted) return;
    if (result == null || result.files.isEmpty) {
      // 用户取消选择器时回落到 URL 网络导入：模拟器/调试场景经 hdc rport
      // 从开发机拉取，真机可走同一 Wi-Fi 的局域网地址。
      final docDir = await getApplicationDocumentsDirectory();
      final url = await _showOhosNetworkImport(docDir.path);
      if (url == null || url.isEmpty || !mounted) return;
      await _downloadAndAddGame(url);
      return;
    }
    final selectedPaths = result.files
        .map((f) => f.path)
        .whereType<String>()
        .toList();
    final cachePaths = selectedPaths
        .where((path) => path.toLowerCase().endsWith('.xp3'))
        .toList();
    // Artemis: a multi-select of `root.pfs` + its `.pfs.000…` patch volumes
    // (+ optional save/config .dat/.ini) is one game — group the copies
    // into a directory named after the base pack.
    final artemisFiles = selectedPaths.where((path) {
      final lower = path.toLowerCase();
      return GameEngine.isPfsVolume(path) ||
          lower.endsWith('.dat') ||
          lower.endsWith('.ini');
    }).toList();
    final hasArtemisPack = artemisFiles.any(GameEngine.isPfsPack);
    if (hasArtemisPack) {
      final docDir = await getApplicationDocumentsDirectory();
      final base = p.basenameWithoutExtension(
        artemisFiles.firstWhere(GameEngine.isPfsPack),
      );
      var destDir = p.join(docDir.path, base);
      var n = 2;
      while (Directory(destDir).existsSync() || File(destDir).existsSync()) {
        destDir = p.join(docDir.path, '$base-${n++}');
      }
      await Directory(destDir).create(recursive: true);
      for (final cachePath in artemisFiles) {
        final dest = p.join(destDir, p.basename(cachePath));
        try {
          await File(cachePath).rename(dest);
        } on FileSystemException {
          await File(cachePath).copy(dest);
          try {
            await File(cachePath).delete();
          } catch (_) {}
        }
      }
      if (!mounted) return;
      final added = await _gameManager.addGame(GameInfo(path: destDir));
      if (!mounted) return;
      if (added) {
        setState(() {});
        _offerScrapeAfterAdd(destDir);
      }
      if (cachePaths.isEmpty) return;
    }
    if (cachePaths.isEmpty || !mounted) {
      if (!hasArtemisPack) {
        UiSnackbar.show(
          context,
          message: l10n.selectGameArchive,
          type: UiSnackbarType.warning,
        );
      }
      return;
    }

    final registered = _gameManager.games.map((g) => g.path).toSet();
    var addedCount = 0;
    String? firstAdded;
    var alreadyCount = 0;
    for (final cachePath in cachePaths) {
      final String destPath = await _adoptOhosCacheFile(cachePath) ?? cachePath;
      if (registered.contains(destPath)) {
        alreadyCount++;
        continue;
      }
      final added = await _gameManager.addGame(GameInfo(path: destPath));
      if (added) {
        addedCount++;
        firstAdded ??= destPath;
        registered.add(destPath);
      }
    }
    if (!mounted) return;
    if (addedCount > 0) {
      setState(() {});
      _offerScrapeAfterAdd(firstAdded!);
      if (addedCount > 1 && mounted) {
        UiSnackbar.show(
          context,
          message: l10n.gamesImported(addedCount),
          type: UiSnackbarType.success,
        );
      }
    } else if (alreadyCount > 0) {
      UiSnackbar.show(
        context,
        message: l10n.gameAlreadyExists(p.basename(cachePaths.first)),
        type: UiSnackbarType.warning,
      );
    }
  }

  /// OHOS 目录导入：系统选择器选文件夹，导入其中全部 .xp3。
  ///
  /// 适配层（本地 file_picker fork 的 ArkTS 'dir' 分支）会列出选中文件夹
  /// 里的 .xp3 并逐个拷入应用 cache，以 JSON 字符串（路径数组）回给
  /// getDirectoryPath——这是 OHOS 分支特有的返回约定；其他平台该接口
  /// 返回的是普通目录路径字符串。
  Future<void> _addGameDirectoryOhos() async {
    final l10n = AppLocalizations.of(context)!;
    final raw = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.selectGameDirectory,
    );
    if (raw == null || raw.isEmpty || !mounted) return;
    final List<dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return;
    }
    if (decoded.isEmpty || !mounted) {
      UiSnackbar.show(
        context,
        message: l10n.noXp3InFolder,
        type: UiSnackbarType.warning,
      );
      return;
    }

    final registered = _gameManager.games.map((g) => g.path).toSet();
    var addedCount = 0;
    String? firstAdded;
    for (final cachePath in decoded.cast<String>()) {
      // An Artemis folder comes back as one cache *directory* (pack chain +
      // saves copied together); KiriKiri archives come back as files.
      final destPath = Directory(cachePath).existsSync()
          ? await _adoptOhosCacheDirectory(cachePath)
          : await _adoptOhosCacheFile(cachePath);
      if (destPath == null || registered.contains(destPath)) continue;
      final added = await _gameManager.addGame(GameInfo(path: destPath));
      if (added) {
        addedCount++;
        firstAdded ??= destPath;
        registered.add(destPath);
      }
    }
    if (!mounted) return;
    if (addedCount > 0) {
      setState(() {});
      _offerScrapeAfterAdd(firstAdded!);
      if (addedCount > 1 && mounted) {
        UiSnackbar.show(
          context,
          message: l10n.gamesImported(addedCount),
          type: UiSnackbarType.success,
        );
      }
    } else {
      UiSnackbar.show(
        context,
        message: l10n.gameAlreadyExists(p.basename(decoded.first as String)),
        type: UiSnackbarType.warning,
      );
    }
  }

  /// 把适配层落在应用 cache 的整个游戏目录副本（Artemis 封包链）移入应用
  /// files 目录并返回最终路径；同名目录已存在时追加序号，避免覆盖存档。
  Future<String?> _adoptOhosCacheDirectory(String cacheDir) async {
    final docDir = await getApplicationDocumentsDirectory();
    final base = p.basename(cacheDir);
    var destPath = p.join(docDir.path, base);
    var n = 2;
    while (Directory(destPath).existsSync() || File(destPath).existsSync()) {
      destPath = p.join(docDir.path, '$base-${n++}');
    }
    final picked = Directory(cacheDir);
    try {
      await picked.rename(destPath);
    } on FileSystemException {
      // 跨卷 rename 等异常时退回逐文件拷贝。
      await Directory(destPath).create(recursive: true);
      await for (final entity in picked.list(followLinks: false)) {
        if (entity is File) {
          await entity.copy(p.join(destPath, p.basename(entity.path)));
        }
      }
      try {
        await picked.delete(recursive: true);
      } catch (_) {}
    }
    return destPath;
  }

  /// 把适配层落在应用 cache 的文件副本移入应用 files 目录并返回最终路径。
  Future<String?> _adoptOhosCacheFile(String cachePath) async {
    final docDir = await getApplicationDocumentsDirectory();
    final destPath = p.join(docDir.path, p.basename(cachePath));
    final picked = File(cachePath);
    try {
      if (destPath != cachePath) {
        await picked.rename(destPath);
      }
    } on FileSystemException {
      // 跨卷 rename 等异常时退回拷贝。
      try {
        await File(destPath).delete();
      } catch (_) {}
      await picked.copy(destPath);
      try {
        await picked.delete();
      } catch (_) {}
    }
    return destPath;
  }

  /// OHOS: register games that were side-loaded into the app sandbox (or one
  /// of the developer roots) with `hdc file send`. Finds KiriKiri archives,
  /// unpacked KiriKiri directories and Artemis pack directories alike.
  Future<void> _addGameFromSandbox() async {
    final l10n = AppLocalizations.of(context)!;
    final docDir = await getApplicationDocumentsDirectory();

    // A set: the scan of a root and the direct probe of the same root can
    // both surface <root>/data.xp3.
    // Public games folder first: it is the documented drop location, so
    // anything new there should surface even if the scan roots below fail.
    await _initOhosGamesDir();
    final candidates = <String>{};
    final roots = <Directory>[docDir];
    final publicGames = _ohosGamesDir;
    if (publicGames != null && Directory(publicGames).existsSync()) {
      roots.add(Directory(publicGames));
    }
    for (final root in _ohosExtraScanRoots) {
      if (Directory(root).existsSync()) roots.add(Directory(root));
    }
    for (final root in roots) {
      for (final dir in _scanSandboxForGameDirectories(root)) {
        candidates.add(dir.path);
      }
      for (final file in _scanSandboxForXp3(root)) {
        candidates.add(file.path);
      }
    }
    for (final root in _ohosExtraScanRoots) {
      // The developer roots are not listable by the app (mode --x for
      // other uids), so directory scans come back empty there — but
      // traversing a KNOWN path is allowed. Probe the conventional
      // KrKr archive name directly.
      final direct = File('$root/data.xp3');
      if (direct.existsSync()) candidates.add(direct.path);
    }
    // Directories are registered as a whole; drop archives that live inside
    // a directory we already list (an unpacked game beside its data.xp3).
    final dirs = candidates.where((c) => Directory(c).existsSync()).toSet();
    candidates.removeWhere(
      (c) => !dirs.contains(c) && dirs.any((d) => p.isWithin(d, c)),
    );

    final registered = _gameManager.games.map((g) => g.path).toSet();
    final fresh = candidates.where((c) => !registered.contains(c)).toList()
      ..sort();
    if (!mounted) return;
    if (fresh.isEmpty) {
      UiSnackbar.show(
        context,
        message: candidates.isEmpty
            ? l10n.noGamesFoundInSandbox
            : l10n.allSandboxGamesRegistered,
        type: UiSnackbarType.info,
      );
      return;
    }

    final String selected;
    if (fresh.length == 1) {
      selected = fresh.first;
    } else {
      final picked = await _pickCandidatePath(fresh);
      if (picked == null || !mounted) return;
      selected = picked;
    }

    final game = GameInfo(path: selected);
    final added = await _gameManager.addGame(game);
    if (!mounted) return;
    if (added) {
      setState(() {});
      _offerScrapeAfterAdd(selected);
    } else {
      UiSnackbar.show(
        context,
        message: l10n.gameAlreadyExists(p.basename(selected)),
        type: UiSnackbarType.warning,
      );
    }
  }

  /// OHOS 网络导入弹窗：输入 URL 拉取 .xp3 到应用沙箱。
  Future<String?> _showOhosNetworkImport(String hintPath) {
    final l10n = AppLocalizations.of(context)!;
    // The emulator debug bridge (`hdc rport tcp:8080 tcp:8080`) forwards the
    // device's loopback:8080 to the development host, so this default works
    // with any static file server on the host.
    const defaultUrl = 'http://127.0.0.1:8080/data.xp3';
    // Build marker: bumped whenever the import flow changes, so the live
    // build can be identified from a screenshot (v2: resume + re-import).
    const flowVersion = 'v4-watchdog';
    final controller = TextEditingController(text: defaultUrl);
    final future = UiDialog.show<String>(
      context,
      title: l10n.selectGameArchive,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '($flowVersion)\n$hintPath',
            style: context.uiType.footnote.copyWith(
              fontFamily: 'monospace',
              color: context.uiColors.textTertiary,
            ),
          ),
          const SizedBox(height: UiSpacing.md),
          UiInput(controller: controller, label: 'URL'),
        ],
      ),
      actions: [
        UiDialogAction(label: l10n.cancel),
        UiDialogAction(
          label: l10n.addGame,
          isDefault: true,
          onPressed: () => Navigator.pop(context, controller.text.trim()),
        ),
      ],
    );
    // 等退场动画结束后再释放输入控制器，避免动画期间访问已释放对象。
    future.whenComplete(
      () => Future<void>.delayed(
        const Duration(milliseconds: 500),
        controller.dispose,
      ),
    );
    return future;
  }

  /// 目录里有多个 XP3 时让用户选择主归档（默认选中第一个）。
  Future<File?> _pickXp3File(List<File> xp3Files) async {
    final picked = await _pickCandidatePath(
      xp3Files.map((f) => f.path).toList(),
    );
    return picked == null ? null : File(picked);
  }

  /// 多个候选（归档或游戏目录）时让用户选择一个（默认选中第一个）。
  /// 每项显示文件名并附引擎标签，便于区分 KiriKiri / Artemis 条目。
  Future<String?> _pickCandidatePath(List<String> paths) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ValueNotifier<int>(0);
    final future = UiDialog.show<String>(
      context,
      title: l10n.selectGameArchive,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 360),
        child: ValueListenableBuilder<int>(
          valueListenable: selected,
          builder: (ctx, idx, _) => ListView.builder(
            shrinkWrap: true,
            itemCount: paths.length,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: UiSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: UiRadio<int>(
                      value: i,
                      groupValue: idx,
                      onChanged: (v) => selected.value = v,
                      label: p.basename(paths[i]),
                    ),
                  ),
                  const SizedBox(width: UiSpacing.sm),
                  UiTag(
                    label: GameEngine.detect(paths[i]).label,
                    tone: GameEngine.detect(paths[i]) == GameEngine.artemis
                        ? UiTagTone.brand
                        : UiTagTone.neutral,
                    dense: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        UiDialogAction(label: l10n.cancel),
        UiDialogAction(
          label: l10n.addGame,
          isDefault: true,
          onPressed: () => Navigator.pop(context, paths[selected.value]),
        ),
      ],
    );
    future.whenComplete(
      () => Future<void>.delayed(
        const Duration(milliseconds: 500),
        selected.dispose,
      ),
    );
    return future;
  }

  /// Downloads a game archive over HTTP into the sandbox and registers it.
  /// This is the OHOS dev/emulator import path: neither `hdc file send` nor
  /// the system picker can deliver multi-GB data into the sandbox, so the
  /// app pulls the file itself (e.g. via `hdc rport tcp:8080 tcp:8080`
  /// tunneling to a static file server on the host).
  Future<void> _downloadAndAddGame(String url) async {
    final l10n = AppLocalizations.of(context)!;
    final docDir = await getApplicationDocumentsDirectory();
    final name = url
        .split('/')
        .lastWhere((s) => s.isNotEmpty, orElse: () => 'data.xp3');
    final dest = File(p.join(docDir.path, name));

    final progress = ValueNotifier<String>('');
    // ignore: unawaited_futures
    UiDialog.show<void>(
      context,
      barrierDismissible: false,
      title: name,
      content: ValueListenableBuilder<String>(
        valueListenable: progress,
        builder: (ctx, text, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const UiLoader(),
            const SizedBox(height: UiSpacing.md),
            Text(
              text,
              textAlign: TextAlign.center,
              style: ctx.uiType.footnote.copyWith(
                fontFamily: 'monospace',
                color: ctx.uiColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );

    String? error;
    try {
      // The rport tunnel can drop the connection mid-stream and Dart's
      // http stream then ends cleanly — a truncated file looks like a
      // successful import. Resume via HTTP Range until the reported
      // Content-Length is fully on disk.
      const int kMaxAttempts = 30;
      var total = 0;
      // Resume a partially-downloaded file from a previous import: probe
      // with a Range offset instead of restarting 2.7 GB from scratch.
      var received = (await dest.exists()) ? await dest.length() : 0;
      for (var attempt = 1; attempt <= kMaxAttempts; attempt++) {
        final client = http.Client();
        try {
          final request = http.Request('GET', Uri.parse(url));
          if (received > 0) {
            request.headers['Range'] = 'bytes=$received-';
          }
          final response = await client.send(request);
          if (response.statusCode == 416 && received > 0) {
            // Offset at/after EOF: the file is already complete.
            total = received;
            break;
          }
          final isResume = response.statusCode == 206 && received > 0;
          if (response.statusCode != 200 && !isResume) {
            throw Exception('HTTP ${response.statusCode}');
          }
          if (response.statusCode == 200 && received > 0) {
            // Server ignored our Range header — appending the full body
            // would corrupt the file.
            throw Exception('server does not support Range resume');
          }
          if (attempt == 1) {
            total = response.contentLength ?? 0;
            if (received > 0 && total > 0) total += received;
          } else if (isResume) {
            // 206 carries the remaining length only.
            if (response.contentLength != null) {
              total = received + response.contentLength!;
            }
          }
          final sink = dest.openWrite(
            mode: received > 0 ? FileMode.append : FileMode.write,
          );
          var lastPace = 0;
          try {
            // 30s inter-chunk watchdog: a dropped tunnel can leave the
            // stream open-but-silent forever; timeout throws and the outer
            // loop resumes from the last flushed offset.
            await for (final chunk in response.stream.timeout(
              const Duration(seconds: 30),
            )) {
              sink.add(chunk);
              received += chunk.length;
              // Pace multi-GB writes: saturating the guest's page cache at
              // loopback speed once took down the emulator's device daemon.
              // A short pause every 16 MB keeps the transfer around
              // 100-150 MB/s and refreshes the progress line.
              if (received - lastPace >= 16 * 1024 * 1024) {
                lastPace = received;
                // Flush at each pace point: IOSink.add only buffers in RAM,
                // so without this the on-disk size (used to resume after a
                // crash/force-stop) lags arbitrarily behind `received`.
                await sink.flush();
                progress.value =
                    '${(received / 1048576).toStringAsFixed(1)} MB'
                    '${total > 0 ? ' / ${(total / 1048576).toStringAsFixed(1)} MB' : ''}';
                await Future<void>.delayed(const Duration(milliseconds: 120));
              }
            }
          } finally {
            await sink.flush();
            await sink.close();
          }
        } finally {
          client.close();
        }
        if (total <= 0 || received >= total) break;
        // Truncated — loop and resume from `received`.
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (total > 0 && received < total) {
        throw Exception(
          'download incomplete: '
          '${(received / 1048576).toStringAsFixed(1)} MB of '
          '${(total / 1048576).toStringAsFixed(1)} MB',
        );
      }
      progress.value =
          '${(received / 1048576).toStringAsFixed(1)} MB'
          '${total > 0 ? ' / ${(total / 1048576).toStringAsFixed(1)} MB' : ''}';
    } catch (e) {
      error = e.toString();
    }

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (error != null) {
      // Never leave a partial file behind — a truncated .xp3 registers as a
      // valid game but corrupts engine startup.
      try {
        if (await dest.exists()) await dest.delete();
      } catch (_) {}
      if (mounted) {
        UiSnackbar.show(
          context,
          message: error,
          type: UiSnackbarType.error,
          duration: const Duration(seconds: 6),
        );
      }
      return;
    }

    final game = GameInfo(path: dest.path);
    final added = await _gameManager.addGame(game);
    if (!mounted) return;
    if (added) {
      setState(() {});
      _offerScrapeAfterAdd(dest.path);
    } else {
      UiSnackbar.show(
        context,
        message: l10n.gameAlreadyExists(p.basename(dest.path)),
        type: UiSnackbarType.warning,
      );
    }
  }

  /// Finds .xp3 archives under [root], up to a small depth so an accidental
  /// scan of a huge tree stays bounded.
  static List<File> _scanSandboxForXp3(Directory root) {
    final results = <File>[];
    void walk(Directory dir, int depth) {
      if (depth > 3) return;
      try {
        for (final entity in dir.listSync(followLinks: false)) {
          if (entity is File && entity.path.toLowerCase().endsWith('.xp3')) {
            results.add(entity);
          } else if (entity is Directory) {
            walk(entity, depth + 1);
          }
        }
      } on FileSystemException {
        // Unreadable entries (pickers' cache, other users' dirs) — skip.
      }
    }

    walk(root, 0);
    results.sort((a, b) => a.path.compareTo(b.path));
    return results;
  }

  /// Finds directories that look like a game root: an unpacked KrKr game
  /// (directly containing a .xp3 archive or a startup.tjs) or an Artemis
  /// game (directly containing a .pfs pack).
  static List<File> _scanSandboxForGameDirectories(Directory root) {
    final results = <File>[];
    void walk(Directory dir, int depth) {
      if (depth > 3) return;
      final List<FileSystemEntity> entries;
      try {
        entries = dir.listSync(followLinks: false).toList();
      } on FileSystemException {
        return;
      }
      for (final entity in entries) {
        if (entity is! Directory) continue;
        try {
          final looksLikeGame = entity
              .listSync(followLinks: false)
              .any(
                (child) =>
                    child is File &&
                    (child.path.toLowerCase().endsWith('.xp3') ||
                        child.path.toLowerCase().endsWith('startup.tjs') ||
                        GameEngine.isPfsPack(child.path)),
              );
          if (looksLikeGame) {
            results.add(File(entity.path));
          } else {
            walk(entity, depth + 1);
          }
        } on FileSystemException {
          continue;
        }
      }
    }

    walk(root, 0);
    results.sort((a, b) => a.path.compareTo(b.path));
    return results;
  }

  void _showIosImportGuide() {
    final l10n = AppLocalizations.of(context)!;
    UiDialog.show<void>(
      context,
      title: l10n.importGames,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.importGamesDesc,
            style: context.uiType.body.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.uiColors.groupedBackground,
              borderRadius: UiRadius.brSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.importStep1,
                  style: context.uiType.body.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.importStep2,
                  style: context.uiType.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.importStep3,
                  style: context.uiType.body.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.importStep4,
                  style: context.uiType.body.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.gamesDirectory,
            style: context.uiType.footnote.copyWith(
              fontFamily: 'monospace',
              color: context.uiColors.textTertiary,
            ),
          ),
        ],
      ),
      actions: [UiDialogAction(label: l10n.gotIt, isDefault: true)],
    );
  }

  Future<void> _showMacosImportGuide() async {
    final l10n = AppLocalizations.of(context)!;
    await UiDialog.show<void>(
      context,
      title: l10n.importGames,
      message: l10n.macosImportTip,
      actions: [UiDialogAction(label: l10n.gotIt, isDefault: true)],
    );
  }

  Future<void> _removeGame(GameInfo game) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await UiDialog.show<bool>(
      context,
      title: l10n.removeGame,
      message: l10n.removeGameConfirm(game.displayTitle),
      actions: [
        UiDialogAction(label: l10n.cancel, returnValue: false),
        UiDialogAction(
          label: l10n.remove,
          isDestructive: true,
          returnValue: true,
        ),
      ],
    );
    if (confirmed == true && mounted) {
      await _gameManager.removeGame(game.path);
      setState(() {});
    }
  }

  Future<void> _renameGame(GameInfo game) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: game.displayTitle);
    final newName = await UiDialog.show<String>(
      context,
      title: l10n.renameGame,
      content: Builder(
        builder: (ctx) => UiInput(
          controller: controller,
          autofocus: true,
          label: l10n.displayTitle,
          onSubmitted: (value) => Navigator.pop(ctx, value),
        ),
      ),
      actions: [
        UiDialogAction(label: l10n.cancel),
        UiDialogAction(
          label: l10n.save,
          isDefault: true,
          onPressed: () => Navigator.pop(context, controller.text),
        ),
      ],
    );
    // 等对话框退场动画结束再释放，避免输入框在动画中访问已释放的 controller。
    Future<void>.delayed(const Duration(milliseconds: 500), controller.dispose);
    if (newName != null && newName.isNotEmpty && mounted) {
      await _gameManager.renameGame(game.path, newName);
      setState(() {});
    }
  }

  void _launchGame(GameInfo game) {
    final l10n = AppLocalizations.of(context)!;
    final dylibPath = _effectiveDylibPath;
    final isSystemLoadedBuiltIn =
        (Platform.isIOS ||
            Platform.isAndroid ||
            Platform.operatingSystem == 'ohos') &&
        _engineMode == EngineMode.builtIn;
    if (dylibPath == null && !isSystemLoadedBuiltIn) {
      final msg = _engineMode == EngineMode.builtIn
          ? l10n.engineNotFoundBuiltIn
          : l10n.engineNotFoundCustom;
      UiSnackbar.show(
        context,
        message: msg,
        type: UiSnackbarType.error,
        actionLabel: l10n.settings,
        onAction: _openSettings,
      );
      return;
    }
    _gameManager.markPlayed(game.path);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GamePage(
          gamePath: game.path,
          title: game.displayTitle,
          coverPath: game.coverPath,
          ffiLibraryPath: dylibPath,
          orientation: _gameOrientation,
          gameManager: _gameManager,
        ),
      ),
    );
  }

  Future<void> _openGameDetail(GameInfo game) async {
    final result = await Navigator.of(context).push<GameDetailResult>(
      MaterialPageRoute<GameDetailResult>(
        builder: (_) => GameDetailPage(game: game, gameManager: _gameManager),
      ),
    );
    if (result == null || !mounted) return;
    if (result.needsRefresh) setState(() {});
    if (result.shouldLaunch) _launchGame(game);
  }

  Future<void> _openGameScrape(GameInfo game) async {
    final result = await Navigator.of(context).push<GameDetailResult>(
      MaterialPageRoute<GameDetailResult>(
        builder: (_) => GameDetailPage(
          game: game,
          gameManager: _gameManager,
          openScrapeOnLoad: true,
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (result.needsRefresh) setState(() {});
    if (result.shouldLaunch) _launchGame(game);
  }

  /// After adding a game, offer to scrape. If user chooses Yes, open detail page with scrape dialog.
  Future<void> _offerScrapeAfterAdd(String addedPath) async {
    final l10n = AppLocalizations.of(context)!;
    final idx = _gameManager.games.indexWhere((g) => g.path == addedPath);
    if (idx < 0 || !mounted) return;
    final game = _gameManager.games[idx];
    final shouldScrape = await UiDialog.show<bool>(
      context,
      title: l10n.scrapeMetadata,
      message: l10n.scrapeAfterAddPrompt,
      actions: [
        UiDialogAction(label: l10n.scrapeAfterAddNo, returnValue: false),
        UiDialogAction(
          label: l10n.scrapeAfterAddYes,
          isDefault: true,
          returnValue: true,
        ),
      ],
    );
    if (shouldScrape != true || !mounted) return;
    await _openGameScrape(game);
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<SettingsResult>(
      MaterialPageRoute<SettingsResult>(
        builder: (_) => SettingsPage(
          engineMode: _engineMode,
          customDylibPath: _customDylibPath,
          builtInDylibPath: _builtInDylibPath,
          builtInAvailable: _builtInAvailable,
          perfOverlay: _perfOverlay,
          fpsLimitEnabled: _fpsLimitEnabled,
          targetFps: _targetFps,
          renderer: _renderer,
          angleBackend: _angleBackend,
          gameOrientation: _gameOrientation,
          restartPending: _restartDeferred,
          publicGamesDir: _ohosGamesDirDisplay,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        // On mobile the engine mode is always builtIn, so we skip updating it.
        if (!Platform.isAndroid &&
            !Platform.isIOS &&
            Platform.operatingSystem != 'ohos') {
          _engineMode = result.engineMode;
          _customDylibPath = result.customDylibPath;
        }
        _perfOverlay = result.perfOverlay;
        _fpsLimitEnabled = result.fpsLimitEnabled;
        _targetFps = result.targetFps;
        _renderer = result.renderer;
        _angleBackend = result.angleBackend;
        _gameOrientation = result.gameOrientation;
        if (result.restartPending) _restartDeferred = true;
      });
    }
  }

  int _gridCrossAxisCount(double width) {
    if (width >= 1200) return 5;
    if (width >= 800) return 4;
    if (width >= 400) return 3;
    return 2;
  }

  List<GameInfo> get _sortedGames {
    final sorted = List<GameInfo>.from(_gameManager.games)
      ..sort((a, b) {
        if (a.lastPlayed != null && b.lastPlayed != null) {
          return b.lastPlayed!.compareTo(a.lastPlayed!);
        }
        if (a.lastPlayed != null) return -1;
        if (b.lastPlayed != null) return 1;
        return a.displayTitle.compareTo(b.displayTitle);
      });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final games = _sortedGames;
    final isDesktop =
        !Platform.isAndroid &&
        !Platform.isIOS &&
        Platform.operatingSystem != 'ohos';
    final topPadding = MediaQuery.of(context).padding.top;
    // Pull-to-refresh rescans the drop folder (iOS: Documents/Games,
    // OHOS: Download/<bundleName>/games). Desktop and Android pick games
    // through a picker, so there is nothing to rescan there.
    final isOhos = Platform.operatingSystem == 'ohos';
    final canPullRefresh = isOhos || Platform.isIOS;

    // The title bar stays put; only the library below it scrolls and pulls.
    final Widget header = Padding(
      padding: EdgeInsets.only(
        top: topPadding + 16,
        left: 20,
        right: 20,
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              l10n.appTitle,
              style: context.uiType.headline.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (isDesktop)
            Tooltip(
              message: _engineMode == EngineMode.builtIn
                  ? (_builtInAvailable
                        ? l10n.builtInReady
                        : l10n.builtInNotReady)
                  : (_customDylibPath != null
                        ? _customDylibPath!.split('/').last
                        : l10n.customNotSet),
              child: Icon(
                _engineMode == EngineMode.builtIn
                    ? LucideIcons.packageOpen
                    : LucideIcons.puzzle,
                color: _engineReady
                    ? context.uiColors.brand
                    : context.uiColors.danger,
                size: 22,
              ),
            ),
          const SizedBox(width: 4),
          if (!Platform.isIOS)
            Builder(
              builder: (btnContext) => UiButton.icon(
                icon: LucideIcons.plus,
                onPressed: () {
                  _addGame(anchor: UiPopupMenu.rectOf(btnContext));
                },
              ),
            ),
          UiButton.icon(icon: LucideIcons.settings, onPressed: _openSettings),
        ],
      ),
    );

    Widget content = CustomScrollView(
      slivers: [
        if (_restartDeferred)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            sliver: SliverToBoxAdapter(
              child: UiBanner(
                tone: UiBannerTone.warning,
                message: l10n.restartPendingBanner,
                actionLabel: l10n.restartNow,
                onAction: restartKrkr2App,
              ),
            ),
          ),
        if (games.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(l10n),
          )
        else
          _buildGameGrid(games, l10n),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
    if (canPullRefresh) {
      content = UiPullRefresh(
        pullingText: l10n.pullToRefresh,
        readyText: l10n.releaseToRefresh,
        refreshingText: l10n.refreshing,
        doneText: l10n.refreshDone,
        onRefresh: () async {
          if (isOhos) {
            await _refreshOhosGames();
          } else {
            await _scanIosGamesDir();
            if (mounted) setState(() {});
          }
        },
        child: content,
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: _loading
          ? const Center(child: UiLoader())
          : Column(
              children: [
                header,
                Expanded(child: content),
              ],
            ),
      floatingActionButton: Platform.isIOS
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UiButton(
                  label: l10n.refresh,
                  leadingIcon: LucideIcons.refreshCw,
                  variant: UiButtonVariant.secondary,
                  onPressed: () async {
                    await _scanIosGamesDir();
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(width: UiSpacing.md),
                UiButton(
                  label: l10n.howToImport,
                  leadingIcon: LucideIcons.circleHelp,
                  onPressed: _showIosImportGuide,
                ),
              ],
            )
          : null,
    );
  }

  /// 引擎状态：显式 dylib 存在，或移动端/OHOS 由系统加载的内置引擎。
  bool get _engineReady {
    if (_effectiveDylibPath != null) return true;
    return (Platform.isAndroid ||
            Platform.isIOS ||
            Platform.operatingSystem == 'ohos') &&
        _engineMode == EngineMode.builtIn;
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    final String description;
    if (Platform.isIOS) {
      description = l10n.noGamesHintIos;
    } else if (Platform.operatingSystem == 'ohos') {
      description = l10n.noGamesHintOhos(
        _ohosGamesDirDisplay ?? 'Download/<bundleName>/games',
      );
    } else {
      description = l10n.noGamesHintDesktop;
    }
    return UiEmpty(
      icon: LucideIcons.gamepad2,
      title: l10n.noGamesYet,
      description: description,
      actionLabel: Platform.isIOS ? l10n.howToImport : l10n.addGame,
      onAction: Platform.isIOS ? _showIosImportGuide : _addGame,
    );
  }

  Widget _buildGameGrid(List<GameInfo> games, AppLocalizations l10n) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _gridCrossAxisCount(constraints.crossAxisExtent);
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3 / 4,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final game = games[index];
              return HomeGameCard(
                game: game,
                l10n: l10n,
                onTap: () => _openGameDetail(game),
                onLaunch: () => _launchGame(game),
                onScrape: () => _openGameScrape(game),
                onRename: () => _renameGame(game),
                onRemove: () => _removeGame(game),
              );
            }, childCount: games.length),
          ),
        );
      },
    );
  }
}

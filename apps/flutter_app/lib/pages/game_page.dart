import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import '../engine/engine_bridge.dart';
import '../engine/flutter_engine_bridge_adapter.dart';
import '../constants/prefs_keys.dart';
import '../l10n/app_localizations.dart';
import '../services/game_manager.dart';
import '../widgets/engine_surface.dart';
import '../ui/ui.dart';
import '../widgets/performance_overlay.dart';

/// The game running page — full-screen engine surface with auto-start flow.
class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    required this.gamePath,
    this.ffiLibraryPath,
    this.engineBridgeBuilder = createEngineBridge,
    this.forceLandscape = true,
    this.gameManager,
  });

  final String gamePath;
  final String? ffiLibraryPath;
  final EngineBridgeBuilder engineBridgeBuilder;
  final bool forceLandscape;

  /// If set, play duration is recorded when leaving this page.
  final GameManager? gameManager;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  static const int _engineResultOk = 0;
  static const MethodChannel _platformChannel = MethodChannel(
    'flutter_engine_bridge',
  );

  late EngineBridge _bridge;
  final GlobalKey<EngineSurfaceState> _surfaceKey =
      GlobalKey<EngineSurfaceState>();

  Ticker? _ticker;
  bool _tickInFlight = false;
  bool _isTicking = false;
  bool _autoPausedByLifecycle = false;
  bool _resumeTickAfterLifecycle = false;
  bool _lifecycleTransitionInFlight = false;

  /// When true, a resume was requested while a pause transition was
  /// still in flight. The pause handler checks this on completion and
  /// triggers a resume automatically.
  bool _pendingLifecycleResumed = false;

  // Frame rate
  int _targetFps = PrefsKeys.defaultFps;
  bool _fpsLimitEnabled = false;

  // Performance overlay
  bool _showPerfOverlay = false;
  String _rendererInfo = '';
  final GlobalKey<EnginePerformanceOverlayState> _perfOverlayKey0 =
      GlobalKey<EnginePerformanceOverlayState>();

  // Orientation
  bool _forceLandscape = true;

  // State
  _EnginePhase _phase = _EnginePhase.initializing;
  String? _errorMessage;
  bool _showOverlay = false;
  bool _showDebug = false;
  int _tickCount = 0;
  final List<String> _logs = [];
  static const int _maxLogs = 2000;

  // ScrollController for boot log auto-scroll
  final ScrollController _bootLogScrollController = ScrollController();
  Timer? _startupPollTimer;
  bool _startupPollInFlight = false;
  Timer? _memoryStatsTimer;
  bool _memoryStatsPollInFlight = false;

  String _playSessionId = '';
  int _playActiveMillis = 0;
  final Stopwatch _playStopwatch = Stopwatch();
  int? _playRunningSinceEpochMs;
  bool _playSessionFinalized = false;

  // Documents dir captured at engine_create — anchor for the Dart-side
  // perf log (readable from shell next to the engine funnel log).
  String? _writablePath;

  @override
  void initState() {
    super.initState();
    _playSessionId = _createPlaySessionId();
    if (widget.gameManager != null) {
      unawaited(_savePendingPlaySession());
    }
    WidgetsBinding.instance.addObserver(this);
    _forceLandscape = widget.forceLandscape;
    _bridge = widget.engineBridgeBuilder(ffiLibraryPath: widget.ffiLibraryPath);
    _loadSettings();
    _applyOrientation();
    _log('Initializing engine for: ${widget.gamePath}');
    if (widget.ffiLibraryPath != null) {
      _log('Using custom dylib: ${widget.ffiLibraryPath}');
    }
    // Defer engine startup until after the first frame is rendered,
    // so the boot-log UI is visible before blocking FFI calls begin.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_autoStart());
      }
    });
  }

  String _createPlaySessionId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '$now-${widget.gamePath.hashCode}-${identityHashCode(this)}';
  }

  void _startPlaySessionRun({bool persist = true}) {
    if (widget.gameManager == null) return;
    if (_playSessionFinalized || _playStopwatch.isRunning) return;
    _playRunningSinceEpochMs = DateTime.now().millisecondsSinceEpoch;
    _playStopwatch.start();
    if (persist) {
      unawaited(_savePendingPlaySession());
    }
  }

  void _stopPlaySessionRun({bool persist = true}) {
    if (widget.gameManager == null) return;
    if (!_playStopwatch.isRunning) return;
    _playStopwatch.stop();
    _playActiveMillis += _playStopwatch.elapsedMilliseconds;
    _playStopwatch.reset();
    _playRunningSinceEpochMs = null;
    if (persist) {
      unawaited(_savePendingPlaySession());
    }
  }

  Future<void> _savePendingPlaySession() async {
    if (widget.gameManager == null || _playSessionId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final activeSeconds = _playActiveMillis ~/ 1000;
    await prefs.setString(
      PrefsKeys.pendingPlaySession,
      jsonEncode({
        'version': 2,
        'sessionId': _playSessionId,
        'path': widget.gamePath,
        'activeSeconds': activeSeconds,
        'isRunning': _playStopwatch.isRunning,
        'runningSinceEpochMs': _playRunningSinceEpochMs ?? 0,
      }),
    );
  }

  Future<void> _clearPendingPlaySession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefsKeys.pendingPlaySession);
  }

  Future<void> _finalizePlaySession() async {
    if (widget.gameManager == null || _playSessionFinalized) return;
    _playSessionFinalized = true;
    _stopPlaySessionRun(persist: false);

    try {
      int seconds = _playActiveMillis ~/ 1000;
      if (seconds > 86400) seconds = 86400;
      if (seconds > 0) {
        await widget.gameManager!.recordPlaySession(
          widget.gamePath,
          seconds,
          _playSessionId,
        );
      }
    } finally {
      await _clearPendingPlaySession();
    }
  }

  @override
  void dispose() {
    if (widget.gameManager != null) {
      unawaited(_finalizePlaySession());
    }
    _stopStartupPolling();
    _stopMemoryStatsPolling();
    _bootLogScrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _stopTickLoop(notify: false);
    unawaited(_bridge.engineDestroy());
    _restoreOrientation();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_resumeForLifecycle());
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // Only pause when the app is truly invisible (hidden/paused).
        // On macOS desktop, switching windows only triggers 'inactive',
        // which should NOT pause the engine — the window is still
        // partially visible and the user expects the game to keep running.
        unawaited(_pauseForLifecycle());
        break;
      case AppLifecycleState.inactive:
        // On mobile, 'inactive' precedes 'hidden'/'paused' so we let those
        // handle the pause. On desktop, 'inactive' is just focus-lost and
        // should be ignored to avoid freezing the game on window switch.
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  // --- Auto-start flow: create → open → tick ---

  String _normalizeGamePath(String raw) {
    var p = raw.trim();
    if (p.startsWith('file://')) {
      p = Uri.parse(p).toFilePath();
    }
    // Engine accepts POSIX absolute paths on Android host mode.
    if (p.startsWith('./')) {
      p = '/${p.substring(2)}';
    }
    return p;
  }

  /// On Android, detect whether the user selected the game's `data/`
  /// sub-directory instead of the game root.
  ///
  /// The kirikiri2 engine expects the project directory to contain
  /// `startup.tjs` (or `data/system/Initialize.tjs`).  When the user
  /// picks a folder whose last component is `data` and it does NOT
  /// contain `startup.tjs` but DOES contain `system/Initialize.tjs`,
  /// we step up one level to the real game root — but ONLY if the
  /// parent directory has `startup.tjs` or `data/` pointing back here.
  Future<String> _adjustGamePathForAndroid(String path) async {
    if (!Platform.isAndroid || _isArchivePath(path)) return path;

    final clean = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;

    // If the current directory already has startup.tjs, it IS the game
    // root (or at least a valid project dir). Do NOT adjust.
    for (final name in ['startup.tjs', 'Startup.tjs', 'STARTUP.TJS']) {
      if (await File('$clean/$name').exists()) {
        _log('Game path has $name — no adjustment needed');
        return path;
      }
    }

    // If <path>/data/system/Initialize.tjs exists, this is already a
    // proper game root that uses the data/ sub-directory layout.
    for (final name in ['initialize.tjs', 'Initialize.tjs']) {
      if (await File('$clean/data/system/$name').exists()) {
        _log('Game path has data/system/$name — no adjustment needed');
        return path;
      }
    }

    // The directory has neither startup.tjs nor data/system/Initialize.tjs.
    // Check if it looks like the user selected the `data/` folder itself:
    //   - last path component is "data"
    //   - contains system/Initialize.tjs directly
    final dirName = clean.substring(clean.lastIndexOf('/') + 1).toLowerCase();
    if (dirName != 'data') {
      // Not a `data/` directory — nothing to adjust.
      return path;
    }

    // Verify system/Initialize.tjs exists in the selected directory.
    bool hasSystemInit = false;
    for (final name in ['initialize.tjs', 'Initialize.tjs']) {
      if (await File('$clean/system/$name').exists()) {
        hasSystemInit = true;
        break;
      }
    }

    if (!hasSystemInit) {
      // Doesn't look like a krkr2 data/ directory either.
      return path;
    }

    // Step up to the parent directory.
    final adjusted = clean.substring(0, clean.lastIndexOf('/'));
    _log('Auto-adjusted game path: $path → $adjusted (selected data/ folder)');
    return adjusted;
  }

  static bool _isArchivePath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.xp3') ||
        lower.endsWith('.zip') ||
        lower.endsWith('.7z') ||
        lower.endsWith('.tar');
  }

  Future<String?> _preflightGamePath(String path) async {
    final l10n = AppLocalizations.of(context);
    try {
      if (_isArchivePath(path)) {
        final file = File(path);
        if (!await file.exists()) {
          return l10n?.archiveNotExist(path);
        }
        return null;
      }

      final dir = Directory(path);
      if (!await dir.exists()) {
        return l10n?.gamePathNotExist(path);
      }

      // Accept either startup.tjs in root or data/system/initialize.tjs
      final startup = File('$path/startup.tjs');
      final init = File('$path/data/system/initialize.tjs');
      final initUpper = File('$path/data/system/Initialize.tjs');
      if (!await startup.exists() &&
          !await init.exists() &&
          !await initUpper.exists()) {
        return l10n?.missingStartupScript(path);
      }
    } catch (e) {
      return AppLocalizations.of(context)?.gamePathCheckFailed(e.toString());
    }
    return null;
  }

  Future<void> _autoStart() async {
    if (Platform.isAndroid) {
      final granted = await _ensureAndroidAllFilesAccess();
      if (!granted) {
        _fail(
          AppLocalizations.of(context)?.androidAllFilesAccess ??
              'All files access is required on Android. '
                  'Please grant permission and open the game again.',
        );
        return;
      }
    }

    setState(() => _phase = _EnginePhase.creating);
    _log('engine_create...');

    // Yield to let the UI paint the current log state before the
    // synchronous FFI call blocks the main thread.
    await Future<void>.delayed(Duration.zero);

    // Give the engine a writable dir in the app sandbox. Native
    // engine_create exports it as KRKR_FILES_DIR (used for saves and as
    // the anchor for the OHOS engine log file).
    String? writablePath;
    String? cachePath;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      writablePath = docDir.path;
      final cacheDir = await getTemporaryDirectory();
      cachePath = cacheDir.path;
    } catch (_) {}
    _writablePath = writablePath;
    _log('engine_create(writable: $writablePath)...');
    final int createResult = await _bridge.engineCreate(
      writablePath: writablePath,
      cachePath: cachePath,
    );
    if (createResult != _engineResultOk) {
      _fail(
        'engine_create failed: result=$createResult, '
        'error=${_bridge.engineGetLastError()}',
      );
      return;
    }
    _log('engine_create => OK');

    // Set renderer pipeline (opengl / software) before opening the game
    final prefs = await SharedPreferences.getInstance();
    final renderer =
        prefs.getString(PrefsKeys.renderer) ?? PrefsKeys.rendererOpengl;
    _log('Setting renderer=$renderer');
    await _bridge.engineSetOption(
      key: PrefsKeys.optionRenderer,
      value: renderer,
    );

    // Set ANGLE backend (gles / vulkan) — Android only, others ignore
    if (Platform.isAndroid) {
      final angleBackend =
          prefs.getString(PrefsKeys.angleBackend) ?? PrefsKeys.angleBackendGles;
      _log('Setting angle_backend=$angleBackend');
      await _bridge.engineSetOption(
        key: PrefsKeys.optionAngleBackend,
        value: angleBackend,
      );
    }

    await _applyMemoryGovernorOptions();

    if (!mounted) return;
    setState(() => _phase = _EnginePhase.opening);
    _stopStartupPolling();
    var normalizedGamePath = _normalizeGamePath(widget.gamePath);
    // On Android, auto-detect if the user selected the data/ folder
    // itself and step up to the real game root.
    normalizedGamePath = await _adjustGamePathForAndroid(normalizedGamePath);
    _log('engine_open_game($normalizedGamePath)...');
    _log('Starting application — this may take a moment...');

    final preflightError = await _preflightGamePath(normalizedGamePath);
    if (preflightError != null) {
      _fail(preflightError);
      return;
    }

    // Yield once so opening logs are painted before the async start call.
    await Future<void>.delayed(Duration.zero);

    final int openResult = await _bridge.engineOpenGameAsync(
      normalizedGamePath,
    );
    if (openResult != _engineResultOk) {
      _fail(
        'engine_open_game_async failed: result=$openResult, '
        'error=${_bridge.engineGetLastError()}',
      );
      return;
    }
    _log('engine_open_game_async => queued');
    _startStartupPolling();
  }

  Future<bool> _ensureAndroidAllFilesAccess() async {
    try {
      final has =
          await _platformChannel.invokeMethod<bool>(
            'hasManageExternalStorage',
          ) ??
          false;
      if (has) return true;
      _log('Requesting Android all-files access permission...');
      await _platformChannel.invokeMethod<bool>('requestManageExternalStorage');
      final hasAfter =
          await _platformChannel.invokeMethod<bool>(
            'hasManageExternalStorage',
          ) ??
          false;
      return hasAfter;
    } catch (e) {
      _log('All-files access check failed: $e');
      return false;
    }
  }

  void _fail(String message) {
    _stopStartupPolling();
    _log('ERROR: $message');
    if (!mounted) return;
    setState(() {
      _phase = _EnginePhase.error;
      _errorMessage = message;
    });
  }

  // --- Tick loop (vsync-driven) ---

  // Track the elapsed timestamp of the last *rendered* frame so that
  // reportFrameDelta receives the true inter-frame interval instead of
  // the vsync interval (which is always ~16ms on a 60Hz display).
  Duration _lastRenderedElapsed = Duration.zero;

  void _startTickLoop() {
    if (_isTicking) return;
    setState(() => _isTicking = true);
    _startPlaySessionRun();
    _log('Tick loop started');
    if (kDebugMode) _startMemoryStatsPolling();

    Duration lastElapsed = Duration.zero;
    _lastRenderedElapsed = Duration.zero;
    _ticker = Ticker((Duration elapsed) async {
      if (_tickInFlight) return;

      final int deltaMs = lastElapsed == Duration.zero
          ? 16
          : (elapsed - lastElapsed).inMilliseconds.clamp(1, 100);
      lastElapsed = elapsed;

      _tickInFlight = true;
      try {
        final int result = await _bridge.engineTick(deltaMs: deltaMs);
        if (!mounted) return;

        if (result != _engineResultOk) {
          _ticker?.stop();
          _stopPlaySessionRun();
          final error = _bridge.engineGetLastError();
          _log('Tick ended: result=$result, error=$error');
          if (error.contains('termination') || error.contains('terminated')) {
            _exitGame();
            return;
          }
          setState(() {
            _isTicking = false;
            _phase = _EnginePhase.error;
            _errorMessage = 'engine_tick failed: $result ($error)';
          });
          return;
        }

        // Read the rendered flag exactly once. We pass it to pollFrame()
        // so that engine_surface does NOT read it a second time (which
        // would always see false because the flag is reset on read).
        final bool rendered = await _bridge.engineGetFrameRenderedFlag();
        if (rendered) {
          if (_rendererInfo.isEmpty) {
            _fetchRendererInfo();
          }
          // Compute the real inter-render interval for accurate FPS.
          final int renderDeltaMs = _lastRenderedElapsed == Duration.zero
              ? deltaMs
              : (elapsed - _lastRenderedElapsed).inMilliseconds.clamp(1, 200);
          _lastRenderedElapsed = elapsed;

          _perfOverlayKey0.currentState?.reportFrameDelta(
            renderDeltaMs.toDouble(),
          );
          // Poll frame immediately after tick, passing the flag so
          // engine_surface skips its own flag read.
          await _surfaceKey.currentState?.pollFrame(rendered: true);
        }
        _tickCount += 1;

        if (_tickCount % 300 == 0) {
          final String dartPerf = EngineSurfacePerf.take();
          _log('Tick alive: count=$_tickCount dartperf $dartPerf');
          _writeDartPerf(dartPerf);
        }
      } finally {
        _tickInFlight = false;
      }
    });
    _ticker!.start();
  }

  void _stopTickLoop({bool notify = true}) {
    _stopPlaySessionRun();
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _stopMemoryStatsPolling();

    _isTicking = false;
    if (notify && mounted) {
      setState(() {});
    }
  }

  void _startMemoryStatsPolling() {
    _stopMemoryStatsPolling();
    _memoryStatsTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!mounted || _phase != _EnginePhase.running || !_isTicking) {
        return;
      }
      if (_memoryStatsPollInFlight) {
        return;
      }
      _memoryStatsPollInFlight = true;
      try {
        final stats = await _bridge.engineGetMemoryStats();
        if (stats == null) {
          return;
        }
        final int graphicUsedMb = stats.graphicCacheBytes ~/ (1024 * 1024);
        final int graphicLimitMb =
            stats.graphicCacheLimitBytes ~/ (1024 * 1024);
        final int psbUsedMb = stats.psbCacheBytes ~/ (1024 * 1024);
        final int xp3SegMb = stats.xp3SegmentCacheBytes ~/ (1024 * 1024);
        _log(
          'MEM rss=${stats.selfUsedMb}MB free=${stats.systemFreeMb}MB '
          'g=${graphicUsedMb}MB/${graphicLimitMb}MB '
          'psb=${psbUsedMb}MB(${stats.psbCacheEntries}/${stats.psbCacheEntryLimit}) '
          'xp3=${xp3SegMb}MB '
          'arc=${stats.archiveCacheEntries}/${stats.archiveCacheLimit} '
          'ap=${stats.autopathCacheEntries}/${stats.autopathCacheLimit} '
          'tbl=${stats.autopathTableEntries}',
        );
      } finally {
        _memoryStatsPollInFlight = false;
      }
    });
  }

  void _stopMemoryStatsPolling() {
    _memoryStatsTimer?.cancel();
    _memoryStatsTimer = null;
  }

  void _startStartupPolling() {
    _stopStartupPolling();
    _startupPollTimer = Timer.periodic(const Duration(milliseconds: 100), (
      _,
    ) async {
      if (!mounted || _phase != _EnginePhase.opening) {
        _stopStartupPolling();
        return;
      }
      if (_startupPollInFlight) {
        return;
      }
      _startupPollInFlight = true;
      try {
        await _drainStartupLogs();
        final state = await _bridge.engineGetStartupState();
        if (!mounted || state == null) {
          return;
        }
        switch (state) {
          case EngineStartupState.idle:
          case EngineStartupState.running:
            return;
          case EngineStartupState.succeeded:
            _stopStartupPolling();
            _log('engine_open_game => OK');
            await _applyFpsLimit();
            if (!mounted) return;
            setState(() => _phase = _EnginePhase.running);
            _startTickLoop();
            return;
          case EngineStartupState.failed:
            _stopStartupPolling();
            _fail(
              'engine_open_game failed: error=${_bridge.engineGetLastError()}',
            );
            return;
        }
      } finally {
        _startupPollInFlight = false;
      }
    });
  }

  void _stopStartupPolling() {
    _startupPollTimer?.cancel();
    _startupPollTimer = null;
  }

  Future<void> _drainStartupLogs() async {
    // Drain in a short burst so high-volume native logs are shown in time
    // during startup and don't overflow the native startup queue.
    for (var i = 0; i < 8; i++) {
      final raw = await _bridge.engineDrainStartupLogs();
      if (raw.isEmpty) {
        break;
      }
      final lines = raw.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          _log(trimmed);
        }
      }
    }
  }

  // --- Lifecycle ---

  Future<void> _pauseForLifecycle() async {
    // If a resume comes while we are still pausing, record it so we
    // can bounce back after the pause finishes.
    if (_lifecycleTransitionInFlight) {
      // Another transition is running — just clear the pending-resume
      // flag; we want to stay paused.
      _pendingLifecycleResumed = false;
      return;
    }
    if (!mounted || _autoPausedByLifecycle || _phase != _EnginePhase.running) {
      return;
    }
    _lifecycleTransitionInFlight = true;
    _pendingLifecycleResumed = false;
    final bool wasTicking = _isTicking;
    if (wasTicking) _stopTickLoop();

    try {
      final int result = await _bridge.enginePause();
      if (result == _engineResultOk && mounted) {
        _autoPausedByLifecycle = true;
        _resumeTickAfterLifecycle = wasTicking;
        _log('Lifecycle paused');
      }
    } finally {
      _lifecycleTransitionInFlight = false;
    }

    // If a resume was requested while the pause was in-flight, honour
    // it now so the engine doesn't stay frozen.
    if (_pendingLifecycleResumed && mounted) {
      _pendingLifecycleResumed = false;
      await _resumeForLifecycle();
    }
  }

  Future<void> _resumeForLifecycle() async {
    // If a pause is still in-flight, record that we want to resume
    // once it completes.
    if (_lifecycleTransitionInFlight) {
      _pendingLifecycleResumed = true;
      return;
    }
    if (!mounted || !_autoPausedByLifecycle) {
      return;
    }
    _lifecycleTransitionInFlight = true;
    _pendingLifecycleResumed = false;

    try {
      final int result = await _bridge.engineResume();
      if (result == _engineResultOk && mounted) {
        final bool resumeTick = _resumeTickAfterLifecycle;
        _autoPausedByLifecycle = false;
        _resumeTickAfterLifecycle = false;
        _log('Lifecycle resumed');
        if (resumeTick) _startTickLoop();
      }
    } finally {
      _lifecycleTransitionInFlight = false;
    }
  }

  // --- Settings ---

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      final fps = prefs.getInt(PrefsKeys.targetFps) ?? PrefsKeys.defaultFps;
      final fpsLimitEnabled = prefs.getBool(PrefsKeys.fpsLimitEnabled) ?? false;
      _forceLandscape = prefs.getBool(PrefsKeys.forceLandscape) ?? true;
      setState(() {
        _showPerfOverlay = prefs.getBool(PrefsKeys.perfOverlay) ?? false;
        _targetFps = fps;
        _fpsLimitEnabled = fpsLimitEnabled;
      });
    }
  }

  void _applyOrientation() {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (_forceLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _restoreOrientation() {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  /// Apply the current fps_limit setting to the C++ engine layer.
  /// When disabled (fpsLimitEnabled=false), sends fps_limit=0 so the
  /// engine renders every vsync. When enabled, sends the target FPS value.
  Future<void> _applyFpsLimit() async {
    final int fpsValue = _fpsLimitEnabled ? _targetFps : 0;
    _log(
      'Setting fps_limit=$fpsValue (enabled=$_fpsLimitEnabled, target=$_targetFps)',
    );
    await _bridge.engineSetOption(
      key: PrefsKeys.optionFpsLimit,
      value: fpsValue.toString(),
    );
  }

  Future<void> _applyMemoryGovernorOptions() async {
    const profile = PrefsKeys.memoryProfileAggressive;
    const budgetMb = 0; // 0 = native auto budget by system memory
    const logIntervalMs = 12000;
    const psbCacheMb = 128;
    const psbCacheEntries = 1024;
    const archiveCacheCount = 20;
    const autoPathCacheCount = 192;

    _log('Setting memory_profile=$profile');
    await _bridge.engineSetOption(
      key: PrefsKeys.optionMemoryProfile,
      value: profile,
    );
    await _bridge.engineSetOption(
      key: PrefsKeys.optionMemoryBudgetMb,
      value: '$budgetMb',
    );
    await _bridge.engineSetOption(
      key: PrefsKeys.optionMemoryLogIntervalMs,
      value: '$logIntervalMs',
    );
    await _bridge.engineSetOption(
      key: PrefsKeys.optionPsbCacheMb,
      value: '$psbCacheMb',
    );
    await _bridge.engineSetOption(
      key: PrefsKeys.optionPsbCacheEntries,
      value: '$psbCacheEntries',
    );
    await _bridge.engineSetOption(
      key: PrefsKeys.optionArchiveCacheCount,
      value: '$archiveCacheCount',
    );
    await _bridge.engineSetOption(
      key: PrefsKeys.optionAutoPathCacheCount,
      value: '$autoPathCacheCount',
    );
  }

  void _fetchRendererInfo() {
    try {
      _rendererInfo = _bridge.engineGetRendererInfo();
      if (mounted) setState(() {});
    } catch (_) {
      // Renderer info is best-effort
    }
  }

  // --- Logging ---

  void _log(String message) {
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    _logs.insert(0, '[$time] $message');
    if (_logs.length > _maxLogs) {
      _logs.removeRange(_maxLogs, _logs.length);
    }
    // Try to update the UI if we're in a loading phase
    if (mounted && _phase != _EnginePhase.running) {
      setState(() {});
    }
  }

  /// Append the periodic Dart-side perf line to perf-dart.log next to the
  /// engine funnel log (Dart print never reaches hilog, so a file under the
  /// app sandbox — reachable from shell via /mnt/debugtmp — is the channel).
  void _writeDartPerf(String line) {
    final String? dir = _writablePath;
    if (dir == null) return;
    final now = DateTime.now();
    final String stamp =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    unawaited(() async {
      try {
        await File(
          '$dir/perf-dart.log',
        ).writeAsString('[$stamp] $line\n', mode: FileMode.append);
      } catch (_) {}
    }());
  }

  // --- UI ---

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
  }

  void _toggleDebug() {
    setState(() => _showDebug = !_showDebug);
  }

  void _exitGame() {
    _stopTickLoop(notify: false);
    _restoreOrientation();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool surfaceActive = _phase == _EnginePhase.running;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen engine surface
          Positioned.fill(
            child: _phase == _EnginePhase.error
                ? _buildErrorView()
                : _phase == _EnginePhase.running
                ? EngineSurface(
                    key: _surfaceKey,
                    bridge: _bridge,
                    active: surfaceActive,
                    surfaceMode: EngineSurfaceMode.gpuZeroCopy,
                    externalTickDriven: _isTicking,
                    onLog: (msg) => _log('surface: $msg'),
                    onError: (msg) => _log('surface error: $msg'),
                  )
                : _buildBootLogView(),
          ),

          // Performance overlay (top-left)
          if (_showPerfOverlay && _phase == _EnginePhase.running)
            EnginePerformanceOverlay(
              key: _perfOverlayKey0,
              rendererInfo: _rendererInfo,
            ),

          // Floating menu button (top-right)
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 8,
            child: AnimatedOpacity(
              opacity: _showOverlay ? 1.0 : 0.6,
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _toggleOverlay,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      _showOverlay ? LucideIcons.x : LucideIcons.menu,
                      color: Colors.white70,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Overlay controls
          if (_showOverlay) _buildOverlay(),

          // Debug panel
          if (_showDebug) _buildDebugPanel(),
        ],
      ),
    );
  }

  Widget _buildBootLogView() {
    // Full-screen terminal-style boot log — no animations that would
    // freeze during synchronous FFI calls.
    final String phaseLabel;
    switch (_phase) {
      case _EnginePhase.initializing:
        phaseLabel = 'INITIALIZING';
        break;
      case _EnginePhase.creating:
        phaseLabel = 'CREATING ENGINE';
        break;
      case _EnginePhase.opening:
        phaseLabel = 'LOADING GAME';
        break;
      default:
        phaseLabel = 'LOADING';
    }

    // Reversed logs so newest is at the bottom (terminal style)
    final reversedLogs = _logs.reversed.toList();

    // Schedule scroll-to-bottom after this frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_bootLogScrollController.hasClients) {
        _bootLogScrollController.jumpTo(
          _bootLogScrollController.position.maxScrollExtent,
        );
      }
    });

    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _phase == _EnginePhase.opening
                          ? Colors.orangeAccent
                          : Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    phaseLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'krkr2 engine',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            // Game path info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white.withValues(alpha: 0.03),
              child: Text(
                widget.gamePath,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Log area — scrollable terminal output
            Expanded(
              child: reversedLogs.isEmpty
                  ? Center(
                      child: Text(
                        'Waiting...',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                          fontFamily: 'monospace',
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _bootLogScrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: reversedLogs.length,
                      itemBuilder: (context, index) {
                        final log = reversedLogs[index];
                        final isError = log.contains('ERROR');
                        final isOk = log.contains('=> OK');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            log,
                            style: TextStyle(
                              color: isError
                                  ? Colors.redAccent
                                  : isOk
                                  ? Colors.greenAccent
                                  : Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                              fontFamily: 'monospace',
                              height: 1.4,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Bottom status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  // Static blinking cursor indicator (just a block char)
                  const Text(
                    '█',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _phase == _EnginePhase.opening
                        ? 'Engine is loading game resources...'
                        : 'Preparing engine...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _exitGame,
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 12,
                        fontFamily: 'monospace',
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.circleAlert,
              color: Colors.redAccent,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.gameEngineError,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _errorMessage ?? l10n.unknownError,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UiButton(
                  label: l10n.back,
                  leadingIcon: LucideIcons.chevronLeft,
                  variant: UiButtonVariant.outline,
                  onPressed: _exitGame,
                ),
                const SizedBox(width: UiSpacing.lg),
                UiButton(
                  label: l10n.retry,
                  leadingIcon: LucideIcons.refreshCw,
                  onPressed: () {
                    setState(() {
                      _phase = _EnginePhase.initializing;
                      _errorMessage = null;
                      _tickCount = 0;
                    });
                    unawaited(_bridge.engineDestroy());
                    _bridge = widget.engineBridgeBuilder(
                      ffiLibraryPath: widget.ffiLibraryPath,
                    );
                    unawaited(_autoStart());
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    final colors = context.uiColors;
    final l10n = AppLocalizations.of(context)!;
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).padding.top + 52,
      child: Material(
        color: colors.surfaceElevated,
        borderRadius: UiRadius.brLg,
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: UiSpacing.sm),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _overlayItem(
                  icon: LucideIcons.bug,
                  label: _showDebug ? l10n.hideDebug : l10n.showDebug,
                  onTap: _toggleDebug,
                ),
                _overlayItem(
                  icon: LucideIcons.pause,
                  label: _isTicking ? l10n.pause : l10n.resume,
                  onTap: () async {
                    if (_isTicking) {
                      _stopTickLoop();
                      await _bridge.enginePause();
                      _log('User paused');
                    } else {
                      await _bridge.engineResume();
                      _startTickLoop();
                      _log('User resumed');
                    }
                    setState(() => _showOverlay = false);
                  },
                ),
                Divider(color: colors.separator, height: 1),
                _overlayItem(
                  icon: LucideIcons.logOut,
                  label: l10n.exitGame,
                  onTap: _exitGame,
                  destructive: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlayItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final color = destructive
        ? context.uiColors.danger
        : context.uiColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: color, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugPanel() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 200,
      child: Material(
        color: Colors.black.withValues(alpha: 0.85),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.white10,
              child: Row(
                children: [
                  Text(
                    'Debug  |  Phase: ${_phase.name}  |  '
                    'Ticks: $_tickCount  |  '
                    'Ticking: $_isTicking',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _logs.clear()),
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _toggleDebug,
                    child: const Icon(
                      LucideIcons.x,
                      color: Colors.white54,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        'No logs',
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      itemBuilder: (context, index) => Text(
                        _logs[index],
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _EnginePhase { initializing, creating, opening, running, error }

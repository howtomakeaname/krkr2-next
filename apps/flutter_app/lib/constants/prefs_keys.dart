import 'dart:io';

/// Centralized SharedPreferences keys and engine option constants.
///
/// All pages (home_page, settings_page, game_page) should reference
/// these constants instead of defining their own copies.
class PrefsKeys {
  PrefsKeys._(); // Prevent instantiation

  // ── SharedPreferences keys ──────────────────────────────────────
  static const String dylibPath = 'krkr2_dylib_path';
  static const String engineMode = 'krkr2_engine_mode';
  static const String perfOverlay = 'krkr2_perf_overlay';
  static const String fpsLimitEnabled = 'krkr2_fps_limit_enabled';
  static const String targetFps = 'krkr2_target_fps';
  static const String renderer = 'krkr2_renderer';
  static const String angleBackend = 'krkr2_angle_backend';
  static const String locale = 'krkr2_locale';
  static const String themeMode = 'krkr2_theme_mode';
  static const String forceLandscape = 'krkr2_force_landscape';

  /// Orientation used while a game runs: one of [gameOrientationValues].
  /// Supersedes the boolean [forceLandscape]; when unset the boolean is
  /// consulted so upgraded installs keep their previous behaviour.
  static const String gameOrientation = 'krkr2_game_orientation';

  /// Pending play session: JSON { "path": "...", "startTime": "ISO8601" }. Cleared on normal exit or applied on next launch.
  static const String pendingPlaySession = 'krkr2_pending_play_session';

  /// Recently settled play session IDs. Used to avoid duplicate crediting.
  static const String settledPlaySessionIds = 'krkr2_settled_play_session_ids';

  /// Rolling play-session history used by the profile activity overview.
  static const String playSessionHistory = 'krkr2_play_session_history';

  // ── Engine option keys (must match C++ ENGINE_OPTION_* constants) ─
  static const String optionAngleBackend = 'angle_backend';
  static const String optionFpsLimit = 'fps_limit';
  static const String optionRenderer = 'renderer';
  static const String optionMemoryProfile = 'memory_profile';
  static const String optionMemoryBudgetMb = 'memory_budget_mb';
  static const String optionMemoryLogIntervalMs = 'memory_log_interval_ms';
  static const String optionPsbCacheMb = 'psb_cache_mb';
  static const String optionPsbCacheEntries = 'psb_cache_entries';
  static const String optionArchiveCacheCount = 'archive_cache_count';
  static const String optionAutoPathCacheCount = 'autopath_cache_count';
  static const String optionEngine = 'engine';

  // ── Engine option values ────────────────────────────────────────
  static const String angleBackendGles = 'gles';
  static const String angleBackendVulkan = 'vulkan';
  static const String rendererOpengl = 'opengl';
  static const String rendererSoftware = 'software';
  static const String memoryProfileBalanced = 'balanced';
  static const String memoryProfileAggressive = 'aggressive';

  // ── Engine mode values ──────────────────────────────────────────
  static const String engineModeBuiltIn = 'builtIn';
  static const String engineModeCustom = 'custom';

  // ── Game orientation values ─────────────────────────────────────
  static const String gameOrientationAuto = 'auto';
  static const String gameOrientationLandscape = 'landscape';
  static const String gameOrientationPortrait = 'portrait';
  static const List<String> gameOrientationValues = [
    gameOrientationLandscape,
    gameOrientationPortrait,
    gameOrientationAuto,
  ];

  /// Whether the platform lets the app steer the window orientation
  /// (SystemChrome.setPreferredOrientations → window.setPreferredOrientation
  /// on OpenHarmony, the usual paths on Android/iOS). Desktop windows have no
  /// orientation.
  static bool get orientationSupported => _isMobilePlatform;

  // ── Default values ──────────────────────────────────────────────
  static const int defaultFps = 60;
  static const List<int> fpsOptions = [30, 60, 120];

  /// Resolve the persisted game orientation, honouring the legacy boolean.
  static String readGameOrientation(
    String? stored, {
    bool? legacyForceLandscape,
  }) {
    if (stored != null && gameOrientationValues.contains(stored)) {
      return stored;
    }
    if (legacyForceLandscape == false) return gameOrientationAuto;
    return gameOrientationLandscape;
  }

  static bool get _isMobilePlatform {
    final os = Platform.operatingSystem;
    return os == 'android' || os == 'ios' || os == 'ohos';
  }
}

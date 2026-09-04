// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'KrKr2 Next';

  @override
  String get settings => 'Settings';

  @override
  String get addGame => 'Add Game';

  @override
  String get refresh => 'Refresh';

  @override
  String get howToImport => 'How to Import';

  @override
  String get noGamesYet => 'No games added yet';

  @override
  String get noGamesHintDesktop =>
      'Click \"Add Game\" to select a game directory';

  @override
  String get noGamesHintIos =>
      'Use the Files app to copy game folders to:\nOn My iPhone > Krkr2 > Games\nThen tap \"Refresh\"';

  @override
  String get importGames => 'Import Games';

  @override
  String get importGamesDesc =>
      'Please copy your game folders to this app\'s directory using the Files app:';

  @override
  String get importStep1 => '1. Open the \"Files\" app on your iPhone';

  @override
  String get importStep2 => '2. Go to: On My iPhone > Krkr2 > Games';

  @override
  String get importStep3 => '3. Copy your game folder into the Games directory';

  @override
  String get importStep4 =>
      '4. Come back and tap \"Refresh\" to detect new games';

  @override
  String get macosImportTip =>
      'Note: Please select the folder containing the XP3 file first before select the target XP3 file due to macOS sandbox restrictions';

  @override
  String get gamesDirectory => 'Games directory: Games/';

  @override
  String get gotIt => 'Got it';

  @override
  String get tabHome => 'Home';

  @override
  String get tabExplore => 'Explore';

  @override
  String get tabManage => 'Manage';

  @override
  String get tabProfile => 'Me';

  @override
  String get search => 'Search';

  @override
  String get searchGamesHint => 'Search games';

  @override
  String get searchNoResults => 'No matching games';

  @override
  String get searchComingSoon => 'Search is coming soon';

  @override
  String get help => 'Help';

  @override
  String get profilePlayTimeTitle => 'Play Time';

  @override
  String get profileLifetime => 'All Time';

  @override
  String get profileLast7Days => 'Last 7 Days';

  @override
  String get profileTrackingHint => 'Your activity trend starts here';

  @override
  String get profileActiveDays => 'Active Days';

  @override
  String get profileGamesPlayed => 'Games Played';

  @override
  String get profileAverageSession => 'Avg. Session';

  @override
  String get profileTopGames => 'Most Played';

  @override
  String get profileStatistics => 'Play Statistics';

  @override
  String get profileViewStatistics => 'View Detailed Statistics';

  @override
  String get profileGameRecords => 'Games';

  @override
  String get profileRecentGame => 'Recently Played';

  @override
  String get profileNoHistory => 'No activity yet';

  @override
  String profilePlaySummary(String duration, int count) {
    return '$duration played · $count games';
  }

  @override
  String get playTimeLessThanMinute => 'Less than 1 min';

  @override
  String playTimeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String playTimeHours(int hours) {
    return '$hours hr';
  }

  @override
  String playTimeHoursMinutes(int hours, int minutes) {
    return '$hours hr $minutes min';
  }

  @override
  String get helpImportTitle => 'Import Games';

  @override
  String get helpImportBody =>
      'Import a complete game folder or an XP3 / PFS pack. On HarmonyOS, you can also place a folder in the app\'s public games directory, then pull to refresh.';

  @override
  String get helpLaunchTitle => 'Launch & Quick Actions';

  @override
  String get helpLaunchBody =>
      'Tap a game card for details. Touch and hold it to launch, scrape metadata, rename, or remove it.';

  @override
  String get removeGame => 'Remove Game';

  @override
  String removeGameConfirm(String title) {
    return 'Remove \"$title\" from the list?\nThis will NOT delete the game files.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get remove => 'Remove';

  @override
  String get renameGame => 'Rename Game';

  @override
  String get displayTitle => 'Display Title';

  @override
  String get save => 'Save';

  @override
  String get done => 'Done';

  @override
  String gameAlreadyExists(String title) {
    return 'Game already exists: $title';
  }

  @override
  String get builtInReady => 'Built-in ✓';

  @override
  String get builtInNotReady => 'Built-in ✗';

  @override
  String get customNotSet => 'Custom (not set)';

  @override
  String get engineNotFoundBuiltIn =>
      'Built-in engine not found. Please use the build script to bundle the engine, or switch to Custom mode in Settings.';

  @override
  String get engineNotFoundCustom =>
      'Engine dylib not set. Please configure it in Settings first.';

  @override
  String lastPlayed(String time) {
    return 'Last played: $time';
  }

  @override
  String playDuration(String duration) {
    return 'Played $duration';
  }

  @override
  String get rename => 'Rename';

  @override
  String get setCover => 'Set Cover';

  @override
  String get coverFromGallery => 'Choose from Gallery';

  @override
  String get coverFromCamera => 'Take Photo';

  @override
  String get coverRemove => 'Remove Cover';

  @override
  String get settingsEngine => 'Engine';

  @override
  String get engineMode => 'Engine Mode';

  @override
  String get builtIn => 'Built-in';

  @override
  String get custom => 'Custom';

  @override
  String get builtInEngineAvailable => 'Built-in engine available';

  @override
  String get builtInEngineNotFound => 'Built-in engine not found';

  @override
  String get builtInEngineHint =>
      'Use the build script to compile and bundle the engine into the app.';

  @override
  String get engineDylibPath => 'Engine dylib path';

  @override
  String get notSetRequired => 'Not set (required)';

  @override
  String get clearPath => 'Clear path';

  @override
  String get browse => 'Browse...';

  @override
  String get selectEngineDylib => 'Select Engine dylib';

  @override
  String get settingsRendering => 'Rendering';

  @override
  String get renderPipeline => 'Render Pipeline';

  @override
  String get renderPipelineHint =>
      'Render pipeline and graphics backend take effect after restarting the app';

  @override
  String get restartRequiredTitle => 'Restart required';

  @override
  String get restartRequiredMessage =>
      'This change takes effect after the app restarts.';

  @override
  String get applyAndRestart => 'Apply and restart';

  @override
  String get restartPendingBanner =>
      'Saved changes are not in effect yet. Restart the app, or tap here to restart now.';

  @override
  String get restartNow => 'Restart app';

  @override
  String get opengl => 'OpenGL';

  @override
  String get software => 'Software';

  @override
  String get graphicsBackend => 'Graphics Backend';

  @override
  String get graphicsBackendHint =>
      'ANGLE translation layer backend (Android only). Requires restart.';

  @override
  String get opengles => 'OpenGL ES';

  @override
  String get vulkan => 'Vulkan';

  @override
  String get performanceOverlay => 'Performance Overlay';

  @override
  String get performanceOverlayDesc => 'Show FPS and graphics API info';

  @override
  String get fpsLimitEnabled => 'Frame Rate Limit';

  @override
  String get fpsLimitEnabledDesc =>
      'Limit engine rendering frequency to save power';

  @override
  String get fpsLimitOff => 'Off (VSync)';

  @override
  String get forceLandscape => 'Lock Landscape';

  @override
  String get forceLandscapeDesc =>
      'Force landscape orientation when running games (recommended for phones)';

  @override
  String get targetFrameRate => 'Target Frame Rate';

  @override
  String get targetFrameRateDesc =>
      'Maximum rendering frequency when limit is enabled';

  @override
  String fpsLabel(int fps) {
    return '$fps FPS';
  }

  @override
  String get settingsGeneral => 'General';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System Default';

  @override
  String get languageEn => 'English';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageJa => '日本語';

  @override
  String get themeMode => 'Theme';

  @override
  String get themeSystem => 'System Default';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get settingsAbout => 'About';

  @override
  String get version => 'Version';

  @override
  String get aboutVersionDesc => 'Iterative testing, not for long-term use';

  @override
  String get aboutAuthor => 'Author';

  @override
  String get aboutEmail => 'Email';

  @override
  String get aboutEmailCopied => 'Email copied to clipboard';

  @override
  String get gameEngineError => 'Engine Error';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get back => 'Back';

  @override
  String get retry => 'Retry';

  @override
  String get hideDebug => 'Close Debug Log';

  @override
  String get showDebug => 'Open Debug Log';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get exitGame => 'Exit Game';

  @override
  String get discard => 'Discard';

  @override
  String get discardChangesMessage => 'Discard unsaved changes?';

  @override
  String get gameTypeXp3 => 'XP3 archive';

  @override
  String get gameTypeDirectory => 'Directory';

  @override
  String archiveNotExist(String path) {
    return 'Archive file does not exist: $path';
  }

  @override
  String gamePathNotExist(String path) {
    return 'Game path does not exist: $path';
  }

  @override
  String missingStartupScript(String path) {
    return 'Missing startup script in: $path\n(looked for startup.tjs and data/system/initialize.tjs)';
  }

  @override
  String gamePathCheckFailed(String error) {
    return 'Game path check failed: $error';
  }

  @override
  String get androidAllFilesAccess =>
      'All files access is required on Android. Please grant permission and open the game again.';

  @override
  String get noXp3InFolder =>
      'No XP3 archive or Artemis pack (.pfs) found in the selected folder.';

  @override
  String get gameTypeArtemis => 'Artemis pack (.pfs)';

  @override
  String gameEngine(String engine) {
    return 'Engine: $engine';
  }

  @override
  String missingArtemisPack(String path) {
    return 'No Artemis pack (.pfs) found in: $path';
  }

  @override
  String get rescanGamesDir => 'Rescan Games Folder';

  @override
  String rescanGamesDirDesc(String path) {
    return 'Find games dropped into $path or sent in with hdc (XP3 / Artemis .pfs)';
  }

  @override
  String get noGamesFoundInSandbox =>
      'No games found in the games folder or app sandbox.';

  @override
  String get allSandboxGamesRegistered =>
      'All games found are already in the library.';

  @override
  String get noNewGamesFound => 'No new games found.';

  @override
  String noGamesHintOhos(String path) {
    return 'Use the Files app to copy a game folder to:\n$path\nthen pull down to refresh';
  }

  @override
  String get settingsGames => 'Games';

  @override
  String get publicGamesDir => 'Games Folder';

  @override
  String publicGamesDirHint(String path) {
    return 'Copy a whole game folder into $path with the Files app, then pull down on the home page to refresh. Tap to copy the path.';
  }

  @override
  String get pullToRefresh => 'Pull to refresh';

  @override
  String get releaseToRefresh => 'Release to refresh';

  @override
  String get refreshing => 'Refreshing';

  @override
  String get refreshDone => 'Refreshed';

  @override
  String get screenOrientation => 'Screen Orientation';

  @override
  String get screenOrientationDesc =>
      'Orientation used while a game is running';

  @override
  String get orientationAuto => 'Follow system';

  @override
  String get orientationLandscape => 'Landscape';

  @override
  String get orientationPortrait => 'Portrait';

  @override
  String get rotateScreen => 'Rotate Screen';

  @override
  String get gameStarting => 'Starting';

  @override
  String get gamePreparingEngine => 'Preparing engine';

  @override
  String get gameOpening => 'Opening game';

  @override
  String get gameLoadingResources => 'Loading resources';

  @override
  String get gameBootLogs => 'Details';

  @override
  String get gameHideBootLogs => 'Hide details';

  @override
  String get engineRestartRequired =>
      'The engine is already running another game. Restart the app to play a different one.';

  @override
  String gamesImported(int count) {
    return '$count games imported';
  }

  @override
  String get selectGameDirectory => 'Select Game Directory';

  @override
  String get selectGameArchive => 'Select Game Archive (XP3 / PFS)';

  @override
  String get addArchive => 'Add XP3';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String hoursAgo(int count) {
    return '$count hours ago';
  }

  @override
  String daysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get packXp3 => 'Pack as XP3';

  @override
  String get unpackXp3 => 'Unpack XP3';

  @override
  String get packingProgress => 'Packing...';

  @override
  String get unpackingProgress => 'Unpacking...';

  @override
  String get packComplete => 'Packed successfully';

  @override
  String get unpackComplete => 'Unpacked successfully';

  @override
  String xp3OperationFailed(String error) {
    return 'Operation failed: $error';
  }

  @override
  String get launchGame => 'Launch Game';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get gameFormat => 'Format';

  @override
  String get gamePath => 'Path';

  @override
  String get gameDescription => 'About';

  @override
  String get gameKeywords => 'Keywords';

  @override
  String get showMore => 'More';

  @override
  String get showLess => 'Less';

  @override
  String get scrapeMetadata => 'Scrape info';

  @override
  String get scrapeMetadataDialogTitle => 'Scrape info';

  @override
  String get scrapeMetadataSearchHint => 'Enter game name to search';

  @override
  String get scrapeMetadataSearch => 'Search';

  @override
  String get scrapeMetadataSelectTitle => 'Select matching game';

  @override
  String get scrapeMetadataNoResults =>
      'No matching games. Try another keyword.';

  @override
  String get scrapeMetadataConfirm => 'Confirm';

  @override
  String get scrapeMetadataSuccess => 'Name and cover updated.';

  @override
  String get scrapeMetadataCoverFailed =>
      'Name updated. Cover failed; you can set it manually.';

  @override
  String get scrapeMetadataEnterName => 'Please enter a game name.';

  @override
  String get scrapeMetadataSourceError =>
      'Source unavailable. Try again later.';

  @override
  String get scrapeMetadataSelectOne => 'Please select a game.';

  @override
  String get scrapeAfterAddPrompt =>
      'Scrape this game? Choose Yes to search and fill in name and cover.';

  @override
  String get scrapeAfterAddNo => 'No';

  @override
  String get scrapeAfterAddYes => 'Yes';
}

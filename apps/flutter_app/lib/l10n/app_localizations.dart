import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'KrKr2 Next'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @addGame.
  ///
  /// In en, this message translates to:
  /// **'Add Game'**
  String get addGame;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @howToImport.
  ///
  /// In en, this message translates to:
  /// **'How to Import'**
  String get howToImport;

  /// No description provided for @noGamesYet.
  ///
  /// In en, this message translates to:
  /// **'No games added yet'**
  String get noGamesYet;

  /// No description provided for @noGamesHintDesktop.
  ///
  /// In en, this message translates to:
  /// **'Click \"Add Game\" to select a game directory'**
  String get noGamesHintDesktop;

  /// No description provided for @noGamesHintIos.
  ///
  /// In en, this message translates to:
  /// **'Use the Files app to copy game folders to:\nOn My iPhone > Krkr2 > Games\nThen tap \"Refresh\"'**
  String get noGamesHintIos;

  /// No description provided for @importGames.
  ///
  /// In en, this message translates to:
  /// **'Import Games'**
  String get importGames;

  /// No description provided for @importGamesDesc.
  ///
  /// In en, this message translates to:
  /// **'Please copy your game folders to this app\'s directory using the Files app:'**
  String get importGamesDesc;

  /// No description provided for @importStep1.
  ///
  /// In en, this message translates to:
  /// **'1. Open the \"Files\" app on your iPhone'**
  String get importStep1;

  /// No description provided for @importStep2.
  ///
  /// In en, this message translates to:
  /// **'2. Go to: On My iPhone > Krkr2 > Games'**
  String get importStep2;

  /// No description provided for @importStep3.
  ///
  /// In en, this message translates to:
  /// **'3. Copy your game folder into the Games directory'**
  String get importStep3;

  /// No description provided for @importStep4.
  ///
  /// In en, this message translates to:
  /// **'4. Come back and tap \"Refresh\" to detect new games'**
  String get importStep4;

  /// No description provided for @macosImportTip.
  ///
  /// In en, this message translates to:
  /// **'Note: Please select the folder containing the XP3 file first before select the target XP3 file due to macOS sandbox restrictions'**
  String get macosImportTip;

  /// No description provided for @gamesDirectory.
  ///
  /// In en, this message translates to:
  /// **'Games directory: Games/'**
  String get gamesDirectory;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @removeGame.
  ///
  /// In en, this message translates to:
  /// **'Remove Game'**
  String get removeGame;

  /// No description provided for @removeGameConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{title}\" from the list?\nThis will NOT delete the game files.'**
  String removeGameConfirm(String title);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @renameGame.
  ///
  /// In en, this message translates to:
  /// **'Rename Game'**
  String get renameGame;

  /// No description provided for @displayTitle.
  ///
  /// In en, this message translates to:
  /// **'Display Title'**
  String get displayTitle;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @gameAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Game already exists: {title}'**
  String gameAlreadyExists(String title);

  /// No description provided for @builtInReady.
  ///
  /// In en, this message translates to:
  /// **'Built-in ✓'**
  String get builtInReady;

  /// No description provided for @builtInNotReady.
  ///
  /// In en, this message translates to:
  /// **'Built-in ✗'**
  String get builtInNotReady;

  /// No description provided for @customNotSet.
  ///
  /// In en, this message translates to:
  /// **'Custom (not set)'**
  String get customNotSet;

  /// No description provided for @engineNotFoundBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in engine not found. Please use the build script to bundle the engine, or switch to Custom mode in Settings.'**
  String get engineNotFoundBuiltIn;

  /// No description provided for @engineNotFoundCustom.
  ///
  /// In en, this message translates to:
  /// **'Engine dylib not set. Please configure it in Settings first.'**
  String get engineNotFoundCustom;

  /// No description provided for @lastPlayed.
  ///
  /// In en, this message translates to:
  /// **'Last played: {time}'**
  String lastPlayed(String time);

  /// No description provided for @playDuration.
  ///
  /// In en, this message translates to:
  /// **'Played {duration}'**
  String playDuration(String duration);

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @setCover.
  ///
  /// In en, this message translates to:
  /// **'Set Cover'**
  String get setCover;

  /// No description provided for @coverFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get coverFromGallery;

  /// No description provided for @coverFromCamera.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get coverFromCamera;

  /// No description provided for @coverRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove Cover'**
  String get coverRemove;

  /// No description provided for @settingsEngine.
  ///
  /// In en, this message translates to:
  /// **'Engine'**
  String get settingsEngine;

  /// No description provided for @engineMode.
  ///
  /// In en, this message translates to:
  /// **'Engine Mode'**
  String get engineMode;

  /// No description provided for @builtIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get builtIn;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @builtInEngineAvailable.
  ///
  /// In en, this message translates to:
  /// **'Built-in engine available'**
  String get builtInEngineAvailable;

  /// No description provided for @builtInEngineNotFound.
  ///
  /// In en, this message translates to:
  /// **'Built-in engine not found'**
  String get builtInEngineNotFound;

  /// No description provided for @builtInEngineHint.
  ///
  /// In en, this message translates to:
  /// **'Use the build script to compile and bundle the engine into the app.'**
  String get builtInEngineHint;

  /// No description provided for @engineDylibPath.
  ///
  /// In en, this message translates to:
  /// **'Engine dylib path'**
  String get engineDylibPath;

  /// No description provided for @notSetRequired.
  ///
  /// In en, this message translates to:
  /// **'Not set (required)'**
  String get notSetRequired;

  /// No description provided for @clearPath.
  ///
  /// In en, this message translates to:
  /// **'Clear path'**
  String get clearPath;

  /// No description provided for @browse.
  ///
  /// In en, this message translates to:
  /// **'Browse...'**
  String get browse;

  /// No description provided for @selectEngineDylib.
  ///
  /// In en, this message translates to:
  /// **'Select Engine dylib'**
  String get selectEngineDylib;

  /// No description provided for @settingsRendering.
  ///
  /// In en, this message translates to:
  /// **'Rendering'**
  String get settingsRendering;

  /// No description provided for @renderPipeline.
  ///
  /// In en, this message translates to:
  /// **'Render Pipeline'**
  String get renderPipeline;

  /// No description provided for @renderPipelineHint.
  ///
  /// In en, this message translates to:
  /// **'Render pipeline and graphics backend take effect after restarting the app'**
  String get renderPipelineHint;

  /// No description provided for @restartRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Restart required'**
  String get restartRequiredTitle;

  /// No description provided for @restartRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'This change takes effect after the app restarts.'**
  String get restartRequiredMessage;

  /// No description provided for @applyAndRestart.
  ///
  /// In en, this message translates to:
  /// **'Apply and restart'**
  String get applyAndRestart;

  /// No description provided for @restartPendingBanner.
  ///
  /// In en, this message translates to:
  /// **'Saved changes are not in effect yet. Restart the app, or tap here to restart now.'**
  String get restartPendingBanner;

  /// No description provided for @restartNow.
  ///
  /// In en, this message translates to:
  /// **'Restart app'**
  String get restartNow;

  /// No description provided for @opengl.
  ///
  /// In en, this message translates to:
  /// **'OpenGL'**
  String get opengl;

  /// No description provided for @software.
  ///
  /// In en, this message translates to:
  /// **'Software'**
  String get software;

  /// No description provided for @graphicsBackend.
  ///
  /// In en, this message translates to:
  /// **'Graphics Backend'**
  String get graphicsBackend;

  /// No description provided for @graphicsBackendHint.
  ///
  /// In en, this message translates to:
  /// **'ANGLE translation layer backend (Android only). Requires restart.'**
  String get graphicsBackendHint;

  /// No description provided for @opengles.
  ///
  /// In en, this message translates to:
  /// **'OpenGL ES'**
  String get opengles;

  /// No description provided for @vulkan.
  ///
  /// In en, this message translates to:
  /// **'Vulkan'**
  String get vulkan;

  /// No description provided for @performanceOverlay.
  ///
  /// In en, this message translates to:
  /// **'Performance Overlay'**
  String get performanceOverlay;

  /// No description provided for @performanceOverlayDesc.
  ///
  /// In en, this message translates to:
  /// **'Show FPS and graphics API info'**
  String get performanceOverlayDesc;

  /// No description provided for @fpsLimitEnabled.
  ///
  /// In en, this message translates to:
  /// **'Frame Rate Limit'**
  String get fpsLimitEnabled;

  /// No description provided for @fpsLimitEnabledDesc.
  ///
  /// In en, this message translates to:
  /// **'Limit engine rendering frequency to save power'**
  String get fpsLimitEnabledDesc;

  /// No description provided for @fpsLimitOff.
  ///
  /// In en, this message translates to:
  /// **'Off (VSync)'**
  String get fpsLimitOff;

  /// No description provided for @forceLandscape.
  ///
  /// In en, this message translates to:
  /// **'Lock Landscape'**
  String get forceLandscape;

  /// No description provided for @forceLandscapeDesc.
  ///
  /// In en, this message translates to:
  /// **'Force landscape orientation when running games (recommended for phones)'**
  String get forceLandscapeDesc;

  /// No description provided for @targetFrameRate.
  ///
  /// In en, this message translates to:
  /// **'Target Frame Rate'**
  String get targetFrameRate;

  /// No description provided for @targetFrameRateDesc.
  ///
  /// In en, this message translates to:
  /// **'Maximum rendering frequency when limit is enabled'**
  String get targetFrameRateDesc;

  /// No description provided for @fpsLabel.
  ///
  /// In en, this message translates to:
  /// **'{fps} FPS'**
  String fpsLabel(int fps);

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get languageSystem;

  /// No description provided for @languageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @languageZh.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageZh;

  /// No description provided for @languageJa.
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get languageJa;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeMode;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @aboutVersionDesc.
  ///
  /// In en, this message translates to:
  /// **'Iterative testing, not for long-term use'**
  String get aboutVersionDesc;

  /// No description provided for @aboutAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get aboutAuthor;

  /// No description provided for @aboutEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get aboutEmail;

  /// No description provided for @aboutEmailCopied.
  ///
  /// In en, this message translates to:
  /// **'Email copied to clipboard'**
  String get aboutEmailCopied;

  /// No description provided for @gameEngineError.
  ///
  /// In en, this message translates to:
  /// **'Engine Error'**
  String get gameEngineError;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @hideDebug.
  ///
  /// In en, this message translates to:
  /// **'Hide Debug'**
  String get hideDebug;

  /// No description provided for @showDebug.
  ///
  /// In en, this message translates to:
  /// **'Show Debug'**
  String get showDebug;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @exitGame.
  ///
  /// In en, this message translates to:
  /// **'Exit Game'**
  String get exitGame;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @discardChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get discardChangesMessage;

  /// No description provided for @gameTypeXp3.
  ///
  /// In en, this message translates to:
  /// **'XP3 archive'**
  String get gameTypeXp3;

  /// No description provided for @gameTypeDirectory.
  ///
  /// In en, this message translates to:
  /// **'Directory'**
  String get gameTypeDirectory;

  /// No description provided for @archiveNotExist.
  ///
  /// In en, this message translates to:
  /// **'Archive file does not exist: {path}'**
  String archiveNotExist(String path);

  /// No description provided for @gamePathNotExist.
  ///
  /// In en, this message translates to:
  /// **'Game path does not exist: {path}'**
  String gamePathNotExist(String path);

  /// No description provided for @missingStartupScript.
  ///
  /// In en, this message translates to:
  /// **'Missing startup script in: {path}\n(looked for startup.tjs and data/system/initialize.tjs)'**
  String missingStartupScript(String path);

  /// No description provided for @gamePathCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Game path check failed: {error}'**
  String gamePathCheckFailed(String error);

  /// No description provided for @androidAllFilesAccess.
  ///
  /// In en, this message translates to:
  /// **'All files access is required on Android. Please grant permission and open the game again.'**
  String get androidAllFilesAccess;

  /// No description provided for @noXp3InFolder.
  ///
  /// In en, this message translates to:
  /// **'No XP3 archive or Artemis pack (.pfs) found in the selected folder.'**
  String get noXp3InFolder;

  /// No description provided for @gameTypeArtemis.
  ///
  /// In en, this message translates to:
  /// **'Artemis pack (.pfs)'**
  String get gameTypeArtemis;

  /// No description provided for @gameEngine.
  ///
  /// In en, this message translates to:
  /// **'Engine: {engine}'**
  String gameEngine(String engine);

  /// No description provided for @missingArtemisPack.
  ///
  /// In en, this message translates to:
  /// **'No Artemis pack (.pfs) found in: {path}'**
  String missingArtemisPack(String path);

  /// No description provided for @rescanGamesDir.
  ///
  /// In en, this message translates to:
  /// **'Rescan Games Folder'**
  String get rescanGamesDir;

  /// No description provided for @rescanGamesDirDesc.
  ///
  /// In en, this message translates to:
  /// **'Find games dropped into {path} or sent in with hdc (XP3 / Artemis .pfs)'**
  String rescanGamesDirDesc(String path);

  /// No description provided for @noGamesFoundInSandbox.
  ///
  /// In en, this message translates to:
  /// **'No games found in the games folder or app sandbox.'**
  String get noGamesFoundInSandbox;

  /// No description provided for @allSandboxGamesRegistered.
  ///
  /// In en, this message translates to:
  /// **'All games found are already in the library.'**
  String get allSandboxGamesRegistered;

  /// No description provided for @noNewGamesFound.
  ///
  /// In en, this message translates to:
  /// **'No new games found.'**
  String get noNewGamesFound;

  /// No description provided for @noGamesHintOhos.
  ///
  /// In en, this message translates to:
  /// **'Use the Files app to copy a game folder to:\n{path}\nthen pull down to refresh'**
  String noGamesHintOhos(String path);

  /// No description provided for @settingsGames.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get settingsGames;

  /// No description provided for @publicGamesDir.
  ///
  /// In en, this message translates to:
  /// **'Games Folder'**
  String get publicGamesDir;

  /// No description provided for @publicGamesDirHint.
  ///
  /// In en, this message translates to:
  /// **'Copy a whole game folder into {path} with the Files app, then pull down on the home page to refresh. Tap to copy the path.'**
  String publicGamesDirHint(String path);

  /// No description provided for @pullToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Pull to refresh'**
  String get pullToRefresh;

  /// No description provided for @releaseToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Release to refresh'**
  String get releaseToRefresh;

  /// No description provided for @refreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing'**
  String get refreshing;

  /// No description provided for @refreshDone.
  ///
  /// In en, this message translates to:
  /// **'Refreshed'**
  String get refreshDone;

  /// No description provided for @screenOrientation.
  ///
  /// In en, this message translates to:
  /// **'Screen Orientation'**
  String get screenOrientation;

  /// No description provided for @screenOrientationDesc.
  ///
  /// In en, this message translates to:
  /// **'Orientation used while a game is running'**
  String get screenOrientationDesc;

  /// No description provided for @orientationAuto.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get orientationAuto;

  /// No description provided for @orientationLandscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get orientationLandscape;

  /// No description provided for @orientationPortrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get orientationPortrait;

  /// No description provided for @rotateScreen.
  ///
  /// In en, this message translates to:
  /// **'Rotate Screen'**
  String get rotateScreen;

  /// No description provided for @gameStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get gameStarting;

  /// No description provided for @gamePreparingEngine.
  ///
  /// In en, this message translates to:
  /// **'Preparing engine'**
  String get gamePreparingEngine;

  /// No description provided for @gameOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening game'**
  String get gameOpening;

  /// No description provided for @gameLoadingResources.
  ///
  /// In en, this message translates to:
  /// **'Loading resources'**
  String get gameLoadingResources;

  /// No description provided for @gameBootLogs.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get gameBootLogs;

  /// No description provided for @gameHideBootLogs.
  ///
  /// In en, this message translates to:
  /// **'Hide details'**
  String get gameHideBootLogs;

  /// No description provided for @engineRestartRequired.
  ///
  /// In en, this message translates to:
  /// **'The engine is already running another game. Restart the app to play a different one.'**
  String get engineRestartRequired;

  /// No description provided for @gamesImported.
  ///
  /// In en, this message translates to:
  /// **'{count} games imported'**
  String gamesImported(int count);

  /// No description provided for @selectGameDirectory.
  ///
  /// In en, this message translates to:
  /// **'Select Game Directory'**
  String get selectGameDirectory;

  /// No description provided for @selectGameArchive.
  ///
  /// In en, this message translates to:
  /// **'Select Game Archive (XP3 / PFS)'**
  String get selectGameArchive;

  /// No description provided for @addArchive.
  ///
  /// In en, this message translates to:
  /// **'Add XP3'**
  String get addArchive;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} hours ago'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(int count);

  /// No description provided for @packXp3.
  ///
  /// In en, this message translates to:
  /// **'Pack as XP3'**
  String get packXp3;

  /// No description provided for @unpackXp3.
  ///
  /// In en, this message translates to:
  /// **'Unpack XP3'**
  String get unpackXp3;

  /// No description provided for @packingProgress.
  ///
  /// In en, this message translates to:
  /// **'Packing...'**
  String get packingProgress;

  /// No description provided for @unpackingProgress.
  ///
  /// In en, this message translates to:
  /// **'Unpacking...'**
  String get unpackingProgress;

  /// No description provided for @packComplete.
  ///
  /// In en, this message translates to:
  /// **'Packed successfully'**
  String get packComplete;

  /// No description provided for @unpackComplete.
  ///
  /// In en, this message translates to:
  /// **'Unpacked successfully'**
  String get unpackComplete;

  /// No description provided for @xp3OperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {error}'**
  String xp3OperationFailed(String error);

  /// No description provided for @launchGame.
  ///
  /// In en, this message translates to:
  /// **'Launch Game'**
  String get launchGame;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @gameFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get gameFormat;

  /// No description provided for @gamePath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get gamePath;

  /// No description provided for @scrapeMetadata.
  ///
  /// In en, this message translates to:
  /// **'Scrape info'**
  String get scrapeMetadata;

  /// No description provided for @scrapeMetadataDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Scrape info'**
  String get scrapeMetadataDialogTitle;

  /// No description provided for @scrapeMetadataSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Enter game name to search'**
  String get scrapeMetadataSearchHint;

  /// No description provided for @scrapeMetadataSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get scrapeMetadataSearch;

  /// No description provided for @scrapeMetadataSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select matching game'**
  String get scrapeMetadataSelectTitle;

  /// No description provided for @scrapeMetadataNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching games. Try another keyword.'**
  String get scrapeMetadataNoResults;

  /// No description provided for @scrapeMetadataConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get scrapeMetadataConfirm;

  /// No description provided for @scrapeMetadataSuccess.
  ///
  /// In en, this message translates to:
  /// **'Name and cover updated.'**
  String get scrapeMetadataSuccess;

  /// No description provided for @scrapeMetadataCoverFailed.
  ///
  /// In en, this message translates to:
  /// **'Name updated. Cover failed; you can set it manually.'**
  String get scrapeMetadataCoverFailed;

  /// No description provided for @scrapeMetadataEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a game name.'**
  String get scrapeMetadataEnterName;

  /// No description provided for @scrapeMetadataSourceError.
  ///
  /// In en, this message translates to:
  /// **'Source unavailable. Try again later.'**
  String get scrapeMetadataSourceError;

  /// No description provided for @scrapeMetadataSelectOne.
  ///
  /// In en, this message translates to:
  /// **'Please select a game.'**
  String get scrapeMetadataSelectOne;

  /// No description provided for @scrapeAfterAddPrompt.
  ///
  /// In en, this message translates to:
  /// **'Scrape this game? Choose Yes to search and fill in name and cover.'**
  String get scrapeAfterAddPrompt;

  /// No description provided for @scrapeAfterAddNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get scrapeAfterAddNo;

  /// No description provided for @scrapeAfterAddYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get scrapeAfterAddYes;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

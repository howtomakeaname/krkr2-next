// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'KrKr2 Next';

  @override
  String get settings => '設定';

  @override
  String get addGame => 'ゲームを追加';

  @override
  String get refresh => '更新';

  @override
  String get howToImport => 'インポート方法';

  @override
  String get noGamesYet => 'ゲームがまだ追加されていません';

  @override
  String get noGamesHintDesktop => '「ゲームを追加」をクリックしてゲームディレクトリを選択してください';

  @override
  String get noGamesHintIos =>
      '「ファイル」アプリでゲームフォルダをコピーしてください：\niPhone内 > Krkr2 > Games\nその後「更新」をタップ';

  @override
  String get importGames => 'ゲームをインポート';

  @override
  String get importGamesDesc =>
      '「ファイル」アプリを使用して、ゲームフォルダをこのアプリのディレクトリにコピーしてください：';

  @override
  String get importStep1 => '1. iPhoneの「ファイル」アプリを開く';

  @override
  String get importStep2 => '2. iPhone内 > Krkr2 > Games に移動';

  @override
  String get importStep3 => '3. ゲームフォルダをGamesディレクトリにコピー';

  @override
  String get importStep4 => '4. アプリに戻り「更新」をタップして新しいゲームを検出';

  @override
  String get macosImportTip =>
      '注意：macOS サンドボックス制限のため、まず XP3 ファイルを含むフォルダを選択し、その後対象の XP3 ファイルを選択してください';

  @override
  String get gamesDirectory => 'ゲームディレクトリ：Games/';

  @override
  String get gotIt => '了解';

  @override
  String get tabHome => 'ホーム';

  @override
  String get tabExplore => '見つける';

  @override
  String get tabManage => '管理';

  @override
  String get tabProfile => 'マイページ';

  @override
  String get search => '検索';

  @override
  String get searchGamesHint => 'ゲームを検索';

  @override
  String get searchNoResults => '一致するゲームがありません';

  @override
  String get searchComingSoon => '検索機能は準備中です';

  @override
  String get help => 'ヘルプ';

  @override
  String get profilePlayTimeTitle => 'プレイ時間';

  @override
  String get profileLifetime => '累計プレイ';

  @override
  String get profileLast7Days => '直近7日間';

  @override
  String get profileTrackingHint => 'プレイ傾向はこれから記録されます';

  @override
  String get profileActiveDays => 'プレイ日数';

  @override
  String get profileGamesPlayed => 'プレイしたゲーム';

  @override
  String get profileAverageSession => '平均プレイ時間';

  @override
  String get profileTopGames => 'よく遊ぶゲーム';

  @override
  String get profileStatistics => 'プレイ統計';

  @override
  String get profileViewStatistics => '詳しい統計を見る';

  @override
  String get profileHonorTitle => '称号';

  @override
  String get profileHonorNewcomer => 'はじめの一歩';

  @override
  String get profileHonorStoryTraveler => '物語の旅人';

  @override
  String get profileHonorImmersedReader => '没入する読者';

  @override
  String get profileHonorVeteran => 'ベテランプレイヤー';

  @override
  String get profileHonorCollector => 'ゲームコレクター';

  @override
  String get profileHonorCurator => '物語の蒐集家';

  @override
  String profileHonorNext(String title) {
    return '次の称号：$title';
  }

  @override
  String profileHonorRemainingBoth(String duration, int count) {
    return 'あと$durationプレイし、$count本のゲームを体験';
  }

  @override
  String profileHonorRemainingTime(String duration) {
    return 'あと$durationプレイ';
  }

  @override
  String profileHonorRemainingGames(int count) {
    return 'あと$count本のゲームを体験';
  }

  @override
  String get profileHonorHighest => '最高の称号に到達しました';

  @override
  String get profileGameRecords => 'ゲーム記録';

  @override
  String get profileRecentGame => '最近プレイしたゲーム';

  @override
  String get profileNoHistory => '記録はありません';

  @override
  String profilePlaySummary(String duration, int count) {
    return 'プレイ時間 $duration · $count本';
  }

  @override
  String get playTimeLessThanMinute => '1分未満';

  @override
  String playTimeMinutes(int minutes) {
    return '$minutes分';
  }

  @override
  String playTimeHours(int hours) {
    return '$hours時間';
  }

  @override
  String playTimeHoursMinutes(int hours, int minutes) {
    return '$hours時間$minutes分';
  }

  @override
  String get helpImportTitle => 'ゲームをインポート';

  @override
  String get helpImportBody =>
      'ゲームフォルダ全体、または XP3 / PFS パックをライブラリに追加します。HarmonyOS では公開ゲームフォルダに配置してから、下に引いて更新することもできます。';

  @override
  String get helpLaunchTitle => '起動とクイック操作';

  @override
  String get helpLaunchBody =>
      'ゲームカードをタップすると詳細を表示します。長押しすると、起動、情報取得、名前変更、削除ができます。';

  @override
  String get removeGame => 'ゲームを削除';

  @override
  String removeGameConfirm(String title) {
    return 'リストから「$title」を削除しますか？\nゲームファイルは削除されません。';
  }

  @override
  String get cancel => 'キャンセル';

  @override
  String get remove => '削除';

  @override
  String get renameGame => 'ゲーム名を変更';

  @override
  String get displayTitle => '表示名';

  @override
  String get save => '保存';

  @override
  String get done => '完了';

  @override
  String gameAlreadyExists(String title) {
    return 'ゲームは既に存在します：$title';
  }

  @override
  String get builtInReady => '内蔵 ✓';

  @override
  String get builtInNotReady => '内蔵 ✗';

  @override
  String get customNotSet => 'カスタム（未設定）';

  @override
  String get engineNotFoundBuiltIn =>
      '内蔵エンジンが見つかりません。ビルドスクリプトでエンジンをバンドルするか、設定でカスタムモードに切り替えてください。';

  @override
  String get engineNotFoundCustom => 'エンジンdylibが設定されていません。先に設定で構成してください。';

  @override
  String lastPlayed(String time) {
    return '最終プレイ：$time';
  }

  @override
  String playDuration(String duration) {
    return 'プレイ時間 $duration';
  }

  @override
  String get rename => '名前変更';

  @override
  String get setCover => 'カバーを設定';

  @override
  String get coverFromGallery => 'ギャラリーから選択';

  @override
  String get coverFromCamera => '写真を撮る';

  @override
  String get coverRemove => 'カバーを削除';

  @override
  String get settingsEngine => 'エンジン';

  @override
  String get engineMode => 'エンジンモード';

  @override
  String get builtIn => '内蔵';

  @override
  String get custom => 'カスタム';

  @override
  String get builtInEngineAvailable => '内蔵エンジン利用可能';

  @override
  String get builtInEngineNotFound => '内蔵エンジンが見つかりません';

  @override
  String get builtInEngineHint => 'ビルドスクリプトを使用してエンジンをコンパイルし、アプリにバンドルしてください。';

  @override
  String get engineDylibPath => 'エンジンdylibパス';

  @override
  String get notSetRequired => '未設定（必須）';

  @override
  String get clearPath => 'パスをクリア';

  @override
  String get browse => '参照...';

  @override
  String get selectEngineDylib => 'エンジンdylibを選択';

  @override
  String get settingsRendering => 'レンダリング';

  @override
  String get renderPipeline => 'レンダリングパイプライン';

  @override
  String get renderPipelineHint => 'レンダリングパイプラインとグラフィックスバックエンドはアプリ再起動後に有効になります';

  @override
  String get restartRequiredTitle => '再起動が必要です';

  @override
  String get restartRequiredMessage => 'この変更はアプリを再起動すると有効になります。';

  @override
  String get applyAndRestart => '変更して再起動';

  @override
  String get restartPendingBanner =>
      '保存した変更はまだ有効になっていません。アプリを再起動するか、ここから手動で再起動してください。';

  @override
  String get restartNow => 'アプリを再起動';

  @override
  String get opengl => 'OpenGL';

  @override
  String get software => 'ソフトウェア';

  @override
  String get graphicsBackend => 'グラフィックスバックエンド';

  @override
  String get graphicsBackendHint => 'ANGLE翻訳レイヤーバックエンド（Androidのみ）。再起動が必要です。';

  @override
  String get opengles => 'OpenGL ES';

  @override
  String get vulkan => 'Vulkan';

  @override
  String get performanceOverlay => 'パフォーマンスオーバーレイ';

  @override
  String get performanceOverlayDesc => 'FPSとグラフィックAPI情報を表示';

  @override
  String get fpsLimitEnabled => 'フレームレート制限';

  @override
  String get fpsLimitEnabledDesc => 'エンジンの描画頻度を制限して省電力';

  @override
  String get fpsLimitOff => 'オフ（VSync）';

  @override
  String get forceLandscape => '横画面ロック';

  @override
  String get forceLandscapeDesc => 'ゲーム実行時に横向き表示を強制します（スマートフォン推奨）';

  @override
  String get targetFrameRate => '目標フレームレート';

  @override
  String get targetFrameRateDesc => '制限有効時の最大描画頻度';

  @override
  String fpsLabel(int fps) {
    return '$fps FPS';
  }

  @override
  String get settingsGeneral => '一般';

  @override
  String get language => '言語';

  @override
  String get languageSystem => 'システムに従う';

  @override
  String get languageEn => 'English';

  @override
  String get languageZh => '简体中文';

  @override
  String get languageJa => '日本語';

  @override
  String get themeMode => 'テーマ';

  @override
  String get themeSystem => 'システムに従う';

  @override
  String get themeDark => 'ダーク';

  @override
  String get themeLight => 'ライト';

  @override
  String get settingsAbout => 'バージョン情報';

  @override
  String get version => 'バージョン';

  @override
  String get aboutVersionDesc => '反復テスト中、長期使用はご遠慮ください';

  @override
  String get aboutAuthor => '作者';

  @override
  String get aboutEmail => 'メール';

  @override
  String get aboutEmailCopied => 'メールアドレスをコピーしました';

  @override
  String get gameEngineError => 'エンジンエラー';

  @override
  String get unknownError => '不明なエラー';

  @override
  String get back => '戻る';

  @override
  String get retry => '再試行';

  @override
  String get hideDebug => 'デバッグログを閉じる';

  @override
  String get showDebug => 'デバッグログを開く';

  @override
  String get pause => '一時停止';

  @override
  String get resume => '再開';

  @override
  String get exitGame => 'ゲームを終了';

  @override
  String get discard => '破棄';

  @override
  String get discardChangesMessage => '未保存の変更を破棄しますか？';

  @override
  String get gameTypeXp3 => 'XP3 アーカイブ';

  @override
  String get gameTypeDirectory => 'フォルダ';

  @override
  String archiveNotExist(String path) {
    return 'アーカイブが存在しません: $path';
  }

  @override
  String gamePathNotExist(String path) {
    return 'ゲームパスが存在しません: $path';
  }

  @override
  String missingStartupScript(String path) {
    return '起動スクリプトが見つかりません: $path\n（startup.tjs と data/system/initialize.tjs を確認済み）';
  }

  @override
  String gamePathCheckFailed(String error) {
    return 'ゲームパスの確認に失敗しました: $error';
  }

  @override
  String get androidAllFilesAccess =>
      'Android では「すべてのファイル」へのアクセス権が必要です。許可してからゲームをもう一度開いてください。';

  @override
  String get noXp3InFolder => '選択したフォルダに XP3 アーカイブも Artemis パック（.pfs）も見つかりません。';

  @override
  String get gameTypeArtemis => 'Artemis パック（.pfs）';

  @override
  String gameEngine(String engine) {
    return 'エンジン: $engine';
  }

  @override
  String missingArtemisPack(String path) {
    return 'Artemis パック（.pfs）が見つかりません: $path';
  }

  @override
  String get rescanGamesDir => 'ゲームフォルダを再スキャン';

  @override
  String rescanGamesDirDesc(String path) {
    return '$path に置いた、または hdc で転送したゲームを検索（XP3 / Artemis .pfs）';
  }

  @override
  String get noGamesFoundInSandbox => 'ゲームフォルダとアプリサンドボックスにゲームが見つかりません。';

  @override
  String get allSandboxGamesRegistered => '見つかったゲームはすべてライブラリに登録済みです。';

  @override
  String get noNewGamesFound => '新しいゲームは見つかりませんでした。';

  @override
  String noGamesHintOhos(String path) {
    return '「ファイル」アプリでゲームフォルダを次の場所にコピー：\n$path\nその後、下に引いて更新';
  }

  @override
  String get settingsGames => 'ゲーム';

  @override
  String get publicGamesDir => 'ゲーム保存フォルダ';

  @override
  String publicGamesDirHint(String path) {
    return '「ファイル」アプリでゲームフォルダごと $path にコピーし、ホーム画面で下に引いて更新すると認識されます。タップでパスをコピー。';
  }

  @override
  String get pullToRefresh => '引っ張って更新';

  @override
  String get releaseToRefresh => '離して更新';

  @override
  String get refreshing => '更新中';

  @override
  String get refreshDone => '更新完了';

  @override
  String get screenOrientation => '画面の向き';

  @override
  String get screenOrientationDesc => 'ゲーム実行中に使用する画面の向き';

  @override
  String get orientationAuto => 'システムに従う';

  @override
  String get orientationLandscape => '横向き';

  @override
  String get orientationPortrait => '縦向き';

  @override
  String get rotateScreen => '画面を回転';

  @override
  String get gameStarting => '起動中';

  @override
  String get gamePreparingEngine => 'エンジンを準備';

  @override
  String get gameOpening => 'ゲームを開く';

  @override
  String get gameLoadingResources => 'リソースを読み込み';

  @override
  String get gameBootLogs => '詳細ログ';

  @override
  String get gameHideBootLogs => 'ログを閉じる';

  @override
  String get engineRestartRequired =>
      'エンジンはこのセッションで別のゲームを実行中です。変更するにはアプリを再起動してください。';

  @override
  String gamesImported(int count) {
    return '$count 件のゲームをインポートしました';
  }

  @override
  String get selectGameDirectory => 'ゲームディレクトリを選択';

  @override
  String get selectGameArchive => 'ゲームアーカイブを選択（XP3 / PFS）';

  @override
  String get addArchive => 'XP3 追加';

  @override
  String get justNow => 'たった今';

  @override
  String minutesAgo(int count) {
    return '$count分前';
  }

  @override
  String hoursAgo(int count) {
    return '$count時間前';
  }

  @override
  String daysAgo(int count) {
    return '$count日前';
  }

  @override
  String get packXp3 => 'XP3にパック';

  @override
  String get unpackXp3 => 'XP3を展開';

  @override
  String get packingProgress => 'パック中...';

  @override
  String get unpackingProgress => '展開中...';

  @override
  String get packComplete => 'パック完了';

  @override
  String get unpackComplete => '展開完了';

  @override
  String xp3OperationFailed(String error) {
    return '操作失敗：$error';
  }

  @override
  String get launchGame => 'ゲームを開始';

  @override
  String get copiedToClipboard => 'クリップボードにコピーしました';

  @override
  String get gameFormat => 'フォーマット';

  @override
  String get gamePath => 'パス';

  @override
  String get gameDescription => 'あらすじ';

  @override
  String get gameKeywords => 'キーワード';

  @override
  String get showMore => 'もっと見る';

  @override
  String get showLess => '閉じる';

  @override
  String get scrapeMetadata => '情報を取得';

  @override
  String get scrapeMetadataDialogTitle => '情報を取得';

  @override
  String get scrapeMetadataSearchHint => 'ゲーム名を入力して検索';

  @override
  String get scrapeMetadataSearch => '検索';

  @override
  String get scrapeMetadataSelectTitle => '一致する作品を選択';

  @override
  String get scrapeMetadataNoResults => '一致する作品がありません。別のキーワードをお試しください。';

  @override
  String get scrapeMetadataConfirm => '確定';

  @override
  String get scrapeMetadataSuccess => '名前とカバーを更新しました。';

  @override
  String get scrapeMetadataCoverFailed => '名前を更新しました。カバーの取得に失敗しました。手動で設定できます。';

  @override
  String get scrapeMetadataEnterName => 'ゲーム名を入力してください。';

  @override
  String get scrapeMetadataSourceError => 'データソースが利用できません。しばらくしてから再試行してください。';

  @override
  String get scrapeMetadataSelectOne => '作品を選択してください。';

  @override
  String get scrapeAfterAddPrompt => 'このゲームの情報を取得しますか？「はい」で検索して名前とカバーを設定します。';

  @override
  String get scrapeAfterAddNo => 'いいえ';

  @override
  String get scrapeAfterAddYes => 'はい';
}

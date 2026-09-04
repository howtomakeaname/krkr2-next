import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../flows/game_metadata_scrape_flow.dart';
import '../l10n/app_localizations.dart';
import '../models/game_info.dart';
import '../services/game_manager.dart';
import '../ui/ui.dart';
import '../utils/xp3_utils.dart';
import '../widgets/game_detail_content.dart';

class GameDetailResult {
  final bool needsRefresh;
  final bool removed;
  final bool shouldLaunch;

  const GameDetailResult({
    this.needsRefresh = false,
    this.removed = false,
    this.shouldLaunch = false,
  });
}

class GameDetailPage extends StatefulWidget {
  const GameDetailPage({
    super.key,
    required this.game,
    required this.gameManager,
  });

  final GameInfo game;
  final GameManager gameManager;

  @override
  State<GameDetailPage> createState() => _GameDetailPageState();
}

class _GameDetailPageState extends State<GameDetailPage> {
  static const double _toolbarCollapseDistance = 240;

  bool _changed = false;
  final GameMetadataScrapeFlow _scrapeFlow = GameMetadataScrapeFlow();
  late final ScrollController _scrollController;
  late final ValueNotifier<double> _toolbarCollapseProgress;

  GameInfo get game => widget.game;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    _toolbarCollapseProgress = ValueNotifier<double>(0);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _toolbarCollapseProgress.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final progress = (_scrollController.offset / _toolbarCollapseDistance)
        .clamp(0.0, 1.0)
        .toDouble();
    if ((progress - _toolbarCollapseProgress.value).abs() > 0.001) {
      _toolbarCollapseProgress.value = progress;
    }
  }

  GameManager get gm => widget.gameManager;
  bool get _isXp3 => game.path.toLowerCase().endsWith('.xp3');
  bool get _hasCover =>
      game.coverPath != null && File(game.coverPath!).existsSync();

  void _pop({bool removed = false}) {
    Navigator.of(context).pop(
      GameDetailResult(needsRefresh: _changed || removed, removed: removed),
    );
  }

  void _launchGame() {
    gm.markPlayed(game.path);
    Navigator.of(
      context,
    ).pop(const GameDetailResult(needsRefresh: true, shouldLaunch: true));
  }

  Rect _fallbackMenuAnchor(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    return Rect.fromLTWH(size.width - 64, pad.top + 4, 44, 44);
  }

  Future<void> _setCover({Rect? anchor}) async {
    final l10n = AppLocalizations.of(context)!;
    final source = await UiPopupMenu.show<String>(
      context,
      anchor: anchor ?? _fallbackMenuAnchor(context),
      items: [
        UiMenuItem(
          label: l10n.coverFromGallery,
          icon: LucideIcons.image,
          value: 'gallery',
        ),
        UiMenuItem(
          label: l10n.coverFromCamera,
          icon: LucideIcons.camera,
          value: 'camera',
        ),
        if (game.coverPath != null)
          UiMenuItem(
            label: l10n.coverRemove,
            icon: LucideIcons.trash2,
            isDestructive: true,
            value: 'remove',
          ),
      ],
    );
    if (source == null || !mounted) return;

    if (source == 'remove') {
      await gm.setCoverImage(game.path, null);
      _changed = true;
      if (mounted) setState(() {});
      return;
    }

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;

    final docDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory('${docDir.path}/covers');
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }
    final ext = image.path.split('.').last;
    final fileName =
        '${game.path.hashCode}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final destPath = '${coversDir.path}/$fileName';
    await File(image.path).copy(destPath);

    if (game.coverPath != null) {
      try {
        final oldFile = File(game.coverPath!);
        if (await oldFile.exists()) await oldFile.delete();
      } catch (_) {}
    }

    await gm.setCoverImage(game.path, destPath);
    _changed = true;
    if (mounted) setState(() {});
  }

  Future<void> _rename() async {
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
      await gm.renameGame(game.path, newName);
      _changed = true;
      if (mounted) setState(() {});
    }
  }

  Future<void> _openScrape() async {
    final applied = await _scrapeFlow.start(
      context,
      game: game,
      gameManager: gm,
    );
    if (applied && mounted) {
      _changed = true;
      setState(() {});
    }
  }

  Future<void> _packUnpack() async {
    final l10n = AppLocalizations.of(context)!;
    final isXp3 = _isXp3;

    final progress = ValueNotifier<double>(0.0);
    final currentFile = ValueNotifier<String>('');

    UiDialog.show<void>(
      context,
      barrierDismissible: false,
      title: isXp3 ? l10n.unpackingProgress : l10n.packingProgress,
      content: PopScope(
        // 操作进行中禁止返回键/手势关闭进度弹窗。
        canPop: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (_, value, _) => UiProgress(value: value),
            ),
            const SizedBox(height: UiSpacing.md),
            ValueListenableBuilder<String>(
              valueListenable: currentFile,
              builder: (ctx, value, _) => Text(
                value,
                style: ctx.uiType.footnote.copyWith(
                  fontFamily: 'monospace',
                  color: ctx.uiColors.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      if (isXp3) {
        final destDir = p.join(
          p.dirname(game.path),
          p.basenameWithoutExtension(game.path),
        );
        await xp3Extract(
          game.path,
          destDir,
          onProgress: (prog, file) {
            progress.value = prog;
            currentFile.value = file;
          },
        );
        if (mounted) {
          Navigator.of(context).pop();
          final newGame = GameInfo(path: destDir);
          await gm.addGame(newGame);
          if (!mounted) return;
          _changed = true;
          UiSnackbar.show(
            context,
            message: l10n.unpackComplete,
            type: UiSnackbarType.success,
          );
        }
      } else {
        final xp3Path = '${game.path}.xp3';
        await xp3Pack(
          game.path,
          xp3Path,
          onProgress: (prog, file) {
            progress.value = prog;
            currentFile.value = file;
          },
        );
        if (mounted) {
          Navigator.of(context).pop();
          final newGame = GameInfo(path: xp3Path);
          await gm.addGame(newGame);
          if (!mounted) return;
          _changed = true;
          UiSnackbar.show(
            context,
            message: l10n.packComplete,
            type: UiSnackbarType.success,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        UiSnackbar.show(
          context,
          message: l10n.xp3OperationFailed(e.toString()),
          type: UiSnackbarType.error,
        );
      }
    } finally {
      progress.dispose();
      currentFile.dispose();
    }
  }

  Future<void> _remove() async {
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
      await gm.removeGame(game.path);
      _pop(removed: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pop();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _buildCollapsingAppBar(l10n),
        body: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopHeroSection(),
              Transform.translate(
                offset: const Offset(0, -GameDetailContent.sheetRadius),
                child: GameDetailContent(
                  key: ValueKey<int>(
                    Object.hash(
                      game.description,
                      Object.hashAll(game.keywords),
                    ),
                  ),
                  game: game,
                  onLaunch: _launchGame,
                  onSetCover: (rect) => _setCover(anchor: rect),
                  onRename: _rename,
                  onScrape: _openScrape,
                  onPackUnpack: _packUnpack,
                  onRemove: _remove,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildCollapsingAppBar(AppLocalizations l10n) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ValueListenableBuilder<double>(
        valueListenable: _toolbarCollapseProgress,
        builder: (context, progress, _) {
          final backgroundProgress = Curves.easeOutCubic.transform(progress);
          final titleProgress = UiCurves.iosSmooth.transform(
            _intervalProgress(progress, 0.42, 1),
          );
          final actionProgress = UiCurves.iosSmooth.transform(
            _intervalProgress(progress, 0.18, 0.92),
          );

          return AppBar(
            backgroundColor: Colors.black.withValues(alpha: backgroundProgress),
            systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.black.withValues(
                alpha: backgroundProgress,
              ),
            ),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            shape: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(
                  alpha: 0.10 * backgroundProgress,
                ),
                width: 0.5,
              ),
            ),
            leading: UiButton.icon(
              icon: LucideIcons.arrowLeft,
              onPressed: _pop,
            ),
            title: Opacity(
              key: const ValueKey<String>('game-detail-toolbar-title'),
              opacity: titleProgress,
              child: Transform.translate(
                offset: Offset(0, 6 * (1 - titleProgress)),
                child: Transform.scale(
                  scale: 0.96 + 0.04 * titleProgress,
                  child: Text(
                    game.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiType.headline.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: UiSpacing.sm),
                child: GameDetailCollapsingLaunchButton(
                  progress: actionProgress,
                  label: l10n.launchGame,
                  onPressed: _launchGame,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double _intervalProgress(double value, double begin, double end) {
    return ((value - begin) / (end - begin)).clamp(0.0, 1.0).toDouble();
  }

  static const double _coverCardAspectRatio = 3 / 4;
  static const double _coverCardWidth = 140;

  /// 顶部一块：高度由内容决定（卡片+标题+开发者），背景毛玻璃随该区域动态填充
  Widget _buildTopHeroSection() {
    final typography = context.uiType;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: _buildBlurredBlock()),
        Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + kToolbarHeight + 24,
            left: 16,
            right: 16,
            bottom: GameDetailContent.sheetRadius + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: _buildTopCoverCard()),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  game.displayTitle,
                  style: typography.title2.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: const [
                      Shadow(
                        color: Color(0xB3000000),
                        blurRadius: 12,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (game.developer != null && game.developer!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    game.developer!,
                    style: typography.body.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w500,
                      shadows: const [
                        Shadow(
                          color: Color(0x99000000),
                          blurRadius: 10,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 仅顶部一块的放大封面 + 强毛玻璃 + 深色渐变遮罩。
  ///
  /// OHOS 上 BackdropFilter 偶尔采不到已经合成的下层图片，因此直接对
  /// 封面做 ImageFiltered，保证不同渲染后端下标题区域都有稳定的模糊度。
  Widget _buildBlurredBlock() {
    return _hasCover
        ? Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ClipRect(
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 38, sigmaY: 38),
                    child: Transform.scale(
                      scale: 1.16,
                      child: Image.file(
                        File(game.coverPath!),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholderBackground(),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.48),
                        Colors.black.withValues(alpha: 0.58),
                        Colors.black.withValues(alpha: 0.78),
                      ],
                      stops: const [0, 0.58, 1],
                    ),
                  ),
                ),
              ),
            ],
          )
        : _buildPlaceholderBackground();
  }

  Widget _buildPlaceholderBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF253047), Color(0xFF090B10)],
        ),
      ),
    );
  }

  /// 顶部居中卡片：仅封面
  Widget _buildTopCoverCard() {
    final height = _coverCardWidth / _coverCardAspectRatio;
    return Card(
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: UiRadius.brLg),
      child: SizedBox(
        width: _coverCardWidth,
        height: height,
        child: _hasCover
            ? UiGameCover(
                image: FileImage(File(game.coverPath!)),
                placeholder: _buildCoverPlaceholder(height),
                filterQuality: FilterQuality.medium,
                semanticLabel: game.displayTitle,
              )
            : _buildCoverPlaceholder(height),
      ),
    );
  }

  Widget _buildCoverPlaceholder(double height) {
    final colors = context.uiColors;
    return Container(
      width: _coverCardWidth,
      height: height,
      color: colors.surfaceElevated,
      child: Icon(
        LucideIcons.gamepad2,
        size: 48,
        color: colors.brand.withValues(alpha: 0.5),
      ),
    );
  }
}

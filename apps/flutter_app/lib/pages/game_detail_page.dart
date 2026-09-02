import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../models/game_engine.dart';
import '../models/game_info.dart';
import '../models/game_metadata_candidate.dart';
import '../services/game_manager.dart';
import '../services/game_metadata_scraper.dart';
import '../ui/ui.dart';
import '../utils/xp3_utils.dart';
import 'scrape_select_page.dart';

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
    this.openScrapeOnLoad = false,
  });

  final GameInfo game;
  final GameManager gameManager;

  /// When true, open the scrape dialog automatically after the first frame (e.g. after adding a game).
  final bool openScrapeOnLoad;

  @override
  State<GameDetailPage> createState() => _GameDetailPageState();
}

class _GameDetailPageState extends State<GameDetailPage> {
  bool _changed = false;
  final GameMetadataScraper _scraper = GameMetadataScraper();

  GameInfo get game => widget.game;

  @override
  void initState() {
    super.initState();
    if (widget.openScrapeOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openScrape();
      });
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
    final l10n = AppLocalizations.of(context)!;

    final controller = TextEditingController(text: game.displayTitle);
    final keyword = await UiDialog.show<String>(
      context,
      title: l10n.scrapeMetadataDialogTitle,
      content: Builder(
        builder: (ctx) => UiInput(
          controller: controller,
          autofocus: true,
          placeholder: l10n.scrapeMetadataSearchHint,
          onSubmitted: (value) => Navigator.pop(ctx, value),
        ),
      ),
      actions: [
        UiDialogAction(label: l10n.cancel),
        UiDialogAction(
          label: l10n.scrapeMetadataSearch,
          isDefault: true,
          onPressed: () => Navigator.pop(context, controller.text),
        ),
      ],
    );
    // 等对话框退场动画结束再释放，避免输入框在动画中访问已释放的 controller。
    Future<void>.delayed(const Duration(milliseconds: 500), controller.dispose);
    if (keyword == null || !mounted) return;
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      UiSnackbar.show(
        context,
        message: l10n.scrapeMetadataEnterName,
        type: UiSnackbarType.warning,
      );
      return;
    }

    UiDialog.show<void>(
      context,
      barrierDismissible: false,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const UiLoader(),
          const SizedBox(height: UiSpacing.md),
          Text(
            l10n.scrapeMetadataSearch,
            style: context.uiType.subheadline.copyWith(
              color: context.uiColors.textSecondary,
            ),
          ),
        ],
      ),
    );

    List<GameMetadataCandidate> candidates;
    try {
      candidates = await _scraper.search(trimmed);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(); // close loading dialog
      if (!mounted) return;
      UiSnackbar.show(
        context,
        message: l10n.scrapeMetadataSourceError,
        type: UiSnackbarType.error,
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // close loading dialog
    if (!mounted) return;
    final applied = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (ctx) => ScrapeSelectPage(
          candidates: candidates,
          game: game,
          gameManager: gm,
          scraper: _scraper,
        ),
      ),
    );
    if (applied == true && mounted) {
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
              builder: (_, value, __) => UiProgress(value: value),
            ),
            const SizedBox(height: UiSpacing.md),
            ValueListenableBuilder<String>(
              valueListenable: currentFile,
              builder: (ctx, value, __) => Text(
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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: UiButton.icon(
            icon: LucideIcons.arrowLeft,
            onPressed: _pop,
          ),
          actions: [
            Builder(
              builder: (btnContext) => UiButton.icon(
                icon: LucideIcons.image,
                onPressed: () {
                  _setCover(anchor: UiPopupMenu.rectOf(btnContext));
                },
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopHeroSection(),
              Transform.translate(
                offset: const Offset(0, -_sheetRadius),
                child: _buildBottomSheet(l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const double _coverCardAspectRatio = 3 / 4;
  static const double _coverCardWidth = 140;

  /// 下方信息块顶部圆角，并与顶部区域留出重叠
  static const double _sheetRadius = 24;

  /// 顶部一块：高度由内容决定（卡片+标题+开发者），背景毛玻璃随该区域动态填充
  Widget _buildTopHeroSection() {
    final colors = context.uiColors;
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
            bottom: _sheetRadius + 16,
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
                    color: colors.textPrimary,
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
                      color: colors.textSecondary,
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

  /// 仅顶部一块的放大封面 + 毛玻璃
  Widget _buildBlurredBlock() {
    return _hasCover
        ? Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Image.file(
                  File(game.coverPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholderBackground(),
                ),
              ),
              Positioned.fill(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
            ],
          )
        : _buildPlaceholderBackground();
  }

  Widget _buildPlaceholderBackground() {
    final colors = context.uiColors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.surfaceElevated, colors.separator],
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
            ? Image.file(
                File(game.coverPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildCoverPlaceholder(height),
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

  /// 下方信息区：实色背景保证可读
  Widget _buildBottomSheet(AppLocalizations l10n) {
    final colors = context.uiColors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_sheetRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoSection(l10n),
          _buildLaunchButton(l10n),
          _buildManageSection(l10n),
          _buildDangerSection(l10n),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoSection(AppLocalizations l10n) {
    final lastPlayed = game.lastPlayed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(
            LucideIcons.folder,
            game.path,
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: game.path));
              UiSnackbar.show(
                context,
                message: l10n.copiedToClipboard,
                type: UiSnackbarType.success,
                duration: const Duration(seconds: 1),
              );
            },
          ),
          if (lastPlayed != null) ...[
            const SizedBox(height: 8),
            _infoRow(
              LucideIcons.clock,
              l10n.lastPlayed(_formatDate(lastPlayed, l10n)),
            ),
          ],
          if ((game.playDurationSeconds ?? 0) >= 60) ...[
            const SizedBox(height: 8),
            _infoRow(
              LucideIcons.timer,
              l10n.playDuration(
                GameInfo.formatPlayDuration(game.playDurationSeconds!),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _infoRow(
            LucideIcons.package,
            game.engine == GameEngine.artemis
                ? l10n.gameTypeArtemis
                : _isXp3
                ? l10n.gameTypeXp3
                : l10n.gameTypeDirectory,
          ),
          const SizedBox(height: 8),
          _infoRow(LucideIcons.cpu, l10n.gameEngine(game.engine.label)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {VoidCallback? onLongPress}) {
    final colors = context.uiColors;
    return GestureDetector(
      onLongPress: onLongPress,
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: context.uiType.footnote.copyWith(
                color: colors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaunchButton(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: UiButton(
        label: l10n.launchGame,
        leadingIcon: LucideIcons.play,
        size: UiButtonSize.large,
        fullWidth: true,
        onPressed: () {
          gm.markPlayed(game.path);
          Navigator.of(
            context,
          ).pop(const GameDetailResult(needsRefresh: true, shouldLaunch: true));
        },
      ),
    );
  }

  Widget _buildManageSection(AppLocalizations l10n) {
    final colors = context.uiColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: UiCard(
        color: colors.surfaceElevated,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            UiListTile(
              icon: LucideIcons.image,
              title: l10n.setCover,
              showChevron: true,
              onTapRect: (rect) => _setCover(anchor: rect),
            ),
            UiListTile(
              icon: LucideIcons.pencil,
              title: l10n.rename,
              showChevron: true,
              onTap: _rename,
            ),
            UiListTile(
              icon: LucideIcons.cloudDownload,
              title: l10n.scrapeMetadata,
              showChevron: true,
              onTap: _openScrape,
            ),
            // XP3 pack/unpack only applies to KiriKiri entries; Artemis
            // packs (.pfs) are consumed in place by the engine.
            if (game.engine == GameEngine.krkr2)
              UiListTile(
                icon: _isXp3 ? LucideIcons.packageOpen : LucideIcons.archive,
                title: _isXp3 ? l10n.unpackXp3 : l10n.packXp3,
                showChevron: true,
                onTap: _packUnpack,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerSection(AppLocalizations l10n) {
    final colors = context.uiColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: UiCard(
        color: colors.surfaceElevated,
        padding: EdgeInsets.zero,
        child: UiListTile(
          icon: LucideIcons.trash2,
          iconColor: colors.danger,
          title: l10n.remove,
          showChevron: true,
          onTap: _remove,
        ),
      ),
    );
  }

  String _formatDate(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return l10n.justNow;
    if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.daysAgo(diff.inDays);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../models/game_info.dart';
import '../models/game_metadata_candidate.dart';
import '../services/cover_downloader.dart';
import '../services/game_manager.dart';
import '../services/game_metadata_scraper.dart';
import '../ui/ui.dart';

/// Step 2 of scrape flow: show search results, let user select one, then apply.
class ScrapeSelectPage extends StatefulWidget {
  const ScrapeSelectPage({
    super.key,
    required this.candidates,
    required this.game,
    required this.gameManager,
    required this.scraper,
  });

  final List<GameMetadataCandidate> candidates;
  final GameInfo game;
  final GameManager gameManager;
  final GameMetadataScraper scraper;

  @override
  State<ScrapeSelectPage> createState() => _ScrapeSelectPageState();
}

class _ScrapeSelectPageState extends State<ScrapeSelectPage> {
  GameMetadataCandidate? _selected;
  bool _applying = false;

  List<GameMetadataCandidate> get candidates => widget.candidates;
  GameInfo get game => widget.game;
  GameManager get gameManager => widget.gameManager;
  GameMetadataScraper get scraper => widget.scraper;

  Widget _buildCandidateLeading(GameMetadataCandidate c) {
    // 列表默认用缩略图，加载快且避免 R18 主图 403
    final displayUrl = (c.thumbnailUrl != null && c.thumbnailUrl!.isNotEmpty)
        ? c.thumbnailUrl!
        : c.coverImageUrl;
    if (displayUrl.isEmpty) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Icon(LucideIcons.imageOff),
      );
    }
    return SizedBox(
      width: 48,
      height: 48,
      child: Image.network(
        displayUrl,
        fit: BoxFit.cover,
        headers: CoverDownloader.imageRequestHeaders,
        errorBuilder: (_, __, ___) => const SizedBox(
          width: 48,
          height: 48,
          child: Icon(LucideIcons.imageOff),
        ),
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const SizedBox(
                width: 48,
                height: 48,
                child: Center(child: UiLoader(size: UiLoaderSize.small)),
              ),
      ),
    );
  }

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selected == null) {
      UiSnackbar.show(
        context,
        message: l10n.scrapeMetadataSelectOne,
        type: UiSnackbarType.warning,
      );
      return;
    }
    setState(() => _applying = true);

    // Description and VNDB tags are intentionally fetched only for the chosen
    // result. The scraper returns the base candidate when this request fails.
    final candidate = await scraper.fetchDetails(_selected!);
    final previousCoverPath = game.coverPath;
    final localPath = await scraper.downloadCover(candidate);
    await gameManager.renameGame(game.path, candidate.title);
    if (localPath != null) {
      await gameManager.setCoverImage(game.path, localPath);
      if (previousCoverPath != null && previousCoverPath != localPath) {
        try {
          final usedByAnotherGame = gameManager.games.any(
            (other) =>
                other.path != game.path && other.coverPath == previousCoverPath,
          );
          if (!usedByAnotherGame) {
            final previousCover = File(previousCoverPath);
            if (await previousCover.exists()) await previousCover.delete();
          }
        } catch (_) {
          // The new cover is already persisted; a stale file is non-fatal.
        }
      }
    }
    await gameManager.setScrapedMetadata(
      game.path,
      developer: candidate.developer,
      description: candidate.details?.description,
      keywords: candidate.details?.keywords,
    );

    if (!mounted) return;
    setState(() => _applying = false);
    UiSnackbar.show(
      context,
      message: localPath != null
          ? l10n.scrapeMetadataSuccess
          : l10n.scrapeMetadataCoverFailed,
      type: UiSnackbarType.success,
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scrapeMetadataSelectTitle),
        leading: _applying
            ? null
            : UiButton.icon(
                icon: LucideIcons.chevronLeft,
                onPressed: () => Navigator.of(context).pop(false),
              ),
      ),
      body: candidates.isEmpty
          ? Center(
              child: UiEmpty(
                icon: LucideIcons.searchX,
                title: l10n.scrapeMetadataNoResults,
                actionLabel: l10n.back,
                onAction: () => Navigator.of(context).pop(false),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: UiSpacing.sm),
                    itemCount: candidates.length,
                    itemBuilder: (context, index) {
                      final c = candidates[index];
                      return UiListTile(
                        leading: _buildCandidateLeading(c),
                        title: c.title,
                        subtitle: c.sourceLabel,
                        trailing: UiRadio<GameMetadataCandidate>(
                          value: c,
                          groupValue: _selected,
                          onChanged: (value) =>
                              setState(() => _selected = value),
                        ),
                        onTap: () => setState(() => _selected = c),
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(UiSpacing.lg),
                    child: Row(
                      children: [
                        UiButton(
                          label: l10n.back,
                          variant: UiButtonVariant.ghost,
                          onPressed: _applying
                              ? null
                              : () => Navigator.of(context).pop(false),
                        ),
                        const SizedBox(width: UiSpacing.lg),
                        Expanded(
                          child: UiButton(
                            label: l10n.scrapeMetadataConfirm,
                            loading: _applying,
                            onPressed: _applying ? null : _confirm,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

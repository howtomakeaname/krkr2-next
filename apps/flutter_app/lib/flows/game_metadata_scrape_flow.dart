import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/game_info.dart';
import '../models/game_metadata_candidate.dart';
import '../pages/scrape_select_page.dart';
import '../services/game_manager.dart';
import '../services/game_metadata_scraper.dart';
import '../ui/ui.dart';

/// Reusable UI flow for searching and applying game metadata.
///
/// Entry pages own only the trigger and their post-success refresh behavior.
/// This flow owns the keyword dialog, loading state, search-result navigation,
/// and the handoff to the candidate-selection page.
class GameMetadataScrapeFlow {
  GameMetadataScrapeFlow({GameMetadataScraper? scraper})
    : _scraper = scraper ?? GameMetadataScraper();

  final GameMetadataScraper _scraper;

  Future<bool> start(
    BuildContext context, {
    required GameInfo game,
    required GameManager gameManager,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final metadataLanguage = Localizations.localeOf(context).toLanguageTag();

    final controller = TextEditingController(text: game.displayTitle);
    final keyword = await UiDialog.show<String>(
      context,
      title: l10n.scrapeMetadataDialogTitle,
      content: Builder(
        builder: (dialogContext) => UiInput(
          controller: controller,
          autofocus: true,
          placeholder: l10n.scrapeMetadataSearchHint,
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
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
    // Keep the controller alive while the dialog performs its exit animation.
    Future<void>.delayed(const Duration(milliseconds: 500), controller.dispose);
    if (keyword == null || !context.mounted) return false;

    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      UiSnackbar.show(
        context,
        message: l10n.scrapeMetadataEnterName,
        type: UiSnackbarType.warning,
      );
      return false;
    }

    // The returned future is intentionally not awaited: this route is closed
    // explicitly after the search request completes.
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
      candidates = await _scraper.search(
        trimmed,
        preferredLanguage: metadataLanguage,
      );
    } catch (_) {
      if (!context.mounted) return false;
      Navigator.of(context).pop();
      if (!context.mounted) return false;
      UiSnackbar.show(
        context,
        message: l10n.scrapeMetadataSourceError,
        type: UiSnackbarType.error,
      );
      return false;
    }

    if (!context.mounted) return false;
    Navigator.of(context).pop();
    if (!context.mounted) return false;

    final applied = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ScrapeSelectPage(
          candidates: candidates,
          game: game,
          gameManager: gameManager,
          scraper: _scraper,
        ),
      ),
    );
    return applied == true;
  }
}

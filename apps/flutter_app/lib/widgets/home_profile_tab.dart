import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../models/game_info.dart';
import '../pages/legal_page.dart';
import '../ui/ui.dart';

/// “我的”页：本机摘要与应用级入口。游玩数据在底部「统计」页。
class HomeProfileTab extends StatelessWidget {
  const HomeProfileTab({
    super.key,
    required this.games,
    required this.onOpenLibrary,
    required this.onOpenGame,
    required this.onOpenSettings,
    required this.onOpenHelp,
    required this.onOpenAbout,
  });

  final List<GameInfo> games;
  final VoidCallback onOpenLibrary;
  final ValueChanged<GameInfo> onOpenGame;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHelp;
  final VoidCallback onOpenAbout;

  GameInfo? get _recentGame {
    GameInfo? recent;
    for (final game in games) {
      final played = game.lastPlayed;
      if (played == null) continue;
      if (recent == null || played.isAfter(recent.lastPlayed!)) {
        recent = game;
      }
    }
    return recent;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.uiColors;

    return ColoredBox(
      color: colors.groupedBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiTabHeader.labeled(title: l10n.tabProfile),
          Expanded(
            child: ListView(
              key: const PageStorageKey<String>('profile-tab-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
              children: [
                _LocalSummaryCard(
                  games: games,
                  recent: _recentGame,
                  onOpenLibrary: onOpenLibrary,
                  onOpenGame: onOpenGame,
                ),
                const SizedBox(height: UiSpacing.lg),
                UiListSection(
                  padding: EdgeInsets.zero,
                  children: [
                    UiListTile(
                      icon: LucideIcons.settings,
                      title: l10n.settings,
                      showChevron: true,
                      onTap: onOpenSettings,
                    ),
                    UiListTile(
                      icon: LucideIcons.circleHelp,
                      title: l10n.help,
                      showChevron: true,
                      onTap: onOpenHelp,
                    ),
                    UiListTile(
                      icon: LucideIcons.info,
                      title: l10n.settingsAbout,
                      showChevron: true,
                      onTap: onOpenAbout,
                    ),
                  ],
                ),
                const SizedBox(height: UiSpacing.lg),
                UiListSection(
                  padding: EdgeInsets.zero,
                  children: [
                    UiListTile(
                      icon: LucideIcons.scale,
                      title: l10n.legalOpenSourceTitle,
                      showChevron: true,
                      onTap: () => _openLegal(context, LegalSection.openSource),
                    ),
                    UiListTile(
                      icon: LucideIcons.shield,
                      title: l10n.legalPrivacyTitle,
                      showChevron: true,
                      onTap: () => _openLegal(context, LegalSection.privacy),
                    ),
                    UiListTile(
                      icon: LucideIcons.fileText,
                      title: l10n.legalDisclaimerTitle,
                      showChevron: true,
                      onTap: () => _openLegal(context, LegalSection.disclaimer),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openLegal(BuildContext context, LegalSection section) {
    UiMotion.push<void>(context, LegalPage(initialSection: section));
  }
}

class _LocalSummaryCard extends StatelessWidget {
  const _LocalSummaryCard({
    required this.games,
    required this.recent,
    required this.onOpenLibrary,
    required this.onOpenGame,
  });

  final List<GameInfo> games;
  final GameInfo? recent;
  final VoidCallback onOpenLibrary;
  final ValueChanged<GameInfo> onOpenGame;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.uiColors;

    return UiCard(
      key: const ValueKey<String>('profile-local-summary-card'),
      borderRadius: UiRadius.brXxl,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpenLibrary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.library, size: 17, color: colors.brand),
                    const SizedBox(width: UiSpacing.sm),
                    Text(
                      l10n.profileLocalSummary,
                      style: context.uiType.footnote.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: UiSpacing.sm),
                Text(
                  '${games.length}',
                  key: const ValueKey<String>('profile-library-row'),
                  style: context.uiType.largeTitle.copyWith(
                    color: colors.textPrimary,
                    fontSize: 34,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: UiSpacing.xs),
                Text(
                  l10n.profileLibraryCount,
                  style: context.uiType.footnote.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: UiSpacing.lg),
          Divider(height: 1, thickness: 0.5, color: colors.separator),
          const SizedBox(height: UiSpacing.sm),
          _RecentGameRow(game: recent, onOpenGame: onOpenGame),
        ],
      ),
    );
  }
}

class _RecentGameRow extends StatelessWidget {
  const _RecentGameRow({required this.game, required this.onOpenGame});

  final GameInfo? game;
  final ValueChanged<GameInfo> onOpenGame;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.uiColors;
    final recent = game;
    final coverPath = recent?.coverPath;
    final hasCover = coverPath != null && File(coverPath).existsSync();

    return GestureDetector(
      key: const ValueKey<String>('profile-recent-row'),
      behavior: HitTestBehavior.opaque,
      onTap: recent == null ? null : () => onOpenGame(recent),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: UiSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: UiGameCover(
                  image: hasCover ? FileImage(File(coverPath)) : null,
                  borderRadius: UiRadius.brSm,
                  semanticLabel: recent?.displayTitle,
                ),
              ),
            ),
            const SizedBox(width: UiSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.profileRecentGame,
                    style: context.uiType.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    recent?.displayTitle ?? l10n.profileNoHistory,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiType.body.copyWith(
                      color: recent == null
                          ? colors.textTertiary
                          : colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (recent != null)
              UiIcon(
                UiIcons.chevronRight,
                size: 16,
                color: colors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

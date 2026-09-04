import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../models/game_info.dart';
import '../ui/ui.dart';

/// “我的”页：本地游玩记录，外加三个应用级入口。
class HomeProfileTab extends StatelessWidget {
  const HomeProfileTab({
    super.key,
    required this.games,
    required this.onOpenSettings,
    required this.onOpenHelp,
    required this.onOpenAbout,
  });

  final List<GameInfo> games;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHelp;
  final VoidCallback onOpenAbout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final topPadding = MediaQuery.paddingOf(context).top;
    final totalSeconds = games.fold<int>(
      0,
      (sum, game) => sum + (game.playDurationSeconds ?? 0),
    );
    final latestGame = _latestPlayedGame(games);

    return ColoredBox(
      color: context.uiColors.groupedBackground,
      child: ListView(
        key: const PageStorageKey<String>('profile-tab-scroll'),
        padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 112),
        children: [
          Text(l10n.tabProfile, style: context.uiType.largeTitle),
          const SizedBox(height: UiSpacing.xl),
          UiCard(
            key: const ValueKey<String>('profile-play-card'),
            borderRadius: UiRadius.brXxl,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.clock3,
                      size: 17,
                      color: context.uiColors.brand,
                    ),
                    const SizedBox(width: UiSpacing.sm),
                    Text(
                      l10n.profilePlayTimeTitle,
                      style: context.uiType.footnote.copyWith(
                        color: context.uiColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: UiSpacing.sm),
                Text(
                  _formatPlayTime(context, totalSeconds),
                  style: context.uiType.largeTitle.copyWith(
                    color: context.uiColors.textPrimary,
                    fontSize: 32,
                  ),
                ),
                const SizedBox(height: UiSpacing.xl),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: context.uiColors.separator,
                ),
                const SizedBox(height: UiSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _ProfileMetric(
                        label: l10n.profileGameRecords,
                        value: games.length.toString(),
                      ),
                    ),
                    Container(
                      width: 0.5,
                      height: 42,
                      color: context.uiColors.separator,
                    ),
                    const SizedBox(width: UiSpacing.lg),
                    Expanded(
                      flex: 2,
                      child: _ProfileMetric(
                        label: l10n.profileRecentGame,
                        value:
                            latestGame?.displayTitle ?? l10n.profileNoHistory,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: UiSpacing.xxl),
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
        ],
      ),
    );
  }

  String _formatPlayTime(BuildContext context, int totalSeconds) {
    final l10n = AppLocalizations.of(context)!;
    final totalMinutes = totalSeconds ~/ 60;
    if (totalMinutes < 60) return l10n.playTimeMinutes(totalMinutes);
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (minutes == 0) return l10n.playTimeHours(hours);
    return l10n.playTimeHoursMinutes(hours, minutes);
  }

  GameInfo? _latestPlayedGame(List<GameInfo> games) {
    GameInfo? latest;
    for (final game in games) {
      final playedAt = game.lastPlayed;
      if (playedAt == null) continue;
      final latestAt = latest?.lastPlayed;
      if (latestAt == null || playedAt.isAfter(latestAt)) latest = game;
    }
    return latest;
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.uiType.caption.copyWith(
            color: context.uiColors.textSecondary,
          ),
        ),
        const SizedBox(height: UiSpacing.xs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.uiType.headline.copyWith(
            color: context.uiColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

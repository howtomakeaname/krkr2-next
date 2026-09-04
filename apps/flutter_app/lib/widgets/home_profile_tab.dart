import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../l10n/play_honor_localizations.dart';
import '../models/game_info.dart';
import '../models/play_insights.dart';
import '../models/play_session.dart';
import '../ui/ui.dart';

/// “我的”页：保留游玩摘要和应用级入口，详细数据进入独立页面查看。
class HomeProfileTab extends StatelessWidget {
  const HomeProfileTab({
    super.key,
    required this.games,
    required this.playSessions,
    required this.onOpenStatistics,
    required this.onOpenSettings,
    required this.onOpenHelp,
    required this.onOpenAbout,
    this.now,
  });

  final List<GameInfo> games;
  final List<PlaySession> playSessions;
  final VoidCallback onOpenStatistics;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHelp;
  final VoidCallback onOpenAbout;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final topPadding = MediaQuery.paddingOf(context).top;
    final insights = PlayInsights.from(
      games: games,
      sessions: playSessions,
      now: now ?? DateTime.now(),
    );

    return ColoredBox(
      color: context.uiColors.groupedBackground,
      child: ListView(
        key: const PageStorageKey<String>('profile-tab-scroll'),
        padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 112),
        children: [
          Text(l10n.tabProfile, style: context.uiType.largeTitle),
          const SizedBox(height: UiSpacing.xl),
          _PlaySummaryPanel(
            insights: insights,
            onOpenStatistics: onOpenStatistics,
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
}

class _PlaySummaryPanel extends StatelessWidget {
  const _PlaySummaryPanel({
    required this.insights,
    required this.onOpenStatistics,
  });

  final PlayInsights insights;
  final VoidCallback onOpenStatistics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.uiColors;

    return UiCard(
      key: const ValueKey<String>('profile-play-card'),
      borderRadius: UiRadius.brXxl,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.clock3, size: 17, color: colors.brand),
                    const SizedBox(width: UiSpacing.sm),
                    Text(
                      l10n.profilePlayTimeTitle,
                      style: context.uiType.footnote.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: UiSpacing.sm),
                Text(
                  _formatPlayTime(l10n, insights.lifetimeSeconds),
                  key: const ValueKey<String>('profile-summary-lifetime'),
                  style: context.uiType.largeTitle.copyWith(
                    color: colors.textPrimary,
                    fontSize: 32,
                    letterSpacing: -0.6,
                  ),
                ),
                Text(
                  l10n.profileLifetime,
                  style: context.uiType.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: UiSpacing.lg),
                Row(
                  children: [
                    Text(
                      l10n.profileLast7Days,
                      style: context.uiType.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatPlayTime(l10n, insights.recentSeconds),
                      key: const ValueKey<String>('profile-summary-week'),
                      style: context.uiType.caption.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: UiSpacing.sm),
                _MiniActivityBars(insights: insights),
              ],
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: colors.separator),
          UiListTile(
            key: const ValueKey<String>('profile-statistics-entry'),
            icon: LucideIcons.award,
            iconColor: colors.brand,
            title: l10n.playHonorTier(insights.honor.tier),
            subtitle: l10n.profileHonorTitle,
            trailingText: l10n.profileStatistics,
            showChevron: true,
            onTap: onOpenStatistics,
          ),
        ],
      ),
    );
  }
}

class _MiniActivityBars extends StatelessWidget {
  const _MiniActivityBars({required this.insights});

  final PlayInsights insights;

  @override
  Widget build(BuildContext context) {
    final maxSeconds = insights.maxDailySeconds;
    final colors = context.uiColors;

    return SizedBox(
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < insights.days.length; index++) ...[
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0,
                    end: maxSeconds == 0
                        ? 0
                        : insights.days[index].seconds / maxSeconds,
                  ),
                  duration: UiDuration.slow,
                  curve: UiCurves.iosSpringOut,
                  builder: (context, value, _) => Container(
                    width: 8,
                    height: maxSeconds == 0 ? 3 : 3 + value * 25,
                    decoration: BoxDecoration(
                      color: insights.days[index].seconds == 0
                          ? colors.separator
                          : colors.brand.withValues(
                              alpha: insights.days[index].isToday ? 1 : 0.5,
                            ),
                      borderRadius: UiRadius.brPill,
                    ),
                  ),
                ),
              ),
            ),
            if (index != insights.days.length - 1)
              const SizedBox(width: UiSpacing.sm),
          ],
        ],
      ),
    );
  }
}

String _formatPlayTime(AppLocalizations l10n, int totalSeconds) {
  if (totalSeconds > 0 && totalSeconds < 60) {
    return l10n.playTimeLessThanMinute;
  }
  final totalMinutes = totalSeconds ~/ 60;
  if (totalMinutes < 60) return l10n.playTimeMinutes(totalMinutes);
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) return l10n.playTimeHours(hours);
  return l10n.playTimeHoursMinutes(hours, minutes);
}

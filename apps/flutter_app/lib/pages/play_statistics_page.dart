import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../l10n/play_honor_localizations.dart';
import '../models/game_info.dart';
import '../models/play_insights.dart';
import '../models/play_session.dart';
import '../ui/ui.dart';

class PlayStatisticsPage extends StatelessWidget {
  const PlayStatisticsPage({
    super.key,
    required this.games,
    required this.playSessions,
    this.now,
  });

  final List<GameInfo> games;
  final List<PlaySession> playSessions;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final insights = PlayInsights.from(
      games: games,
      sessions: playSessions,
      now: now ?? DateTime.now(),
    );

    return Scaffold(
      key: const ValueKey<String>('play-statistics-page'),
      backgroundColor: context.uiColors.groupedBackground,
      appBar: AppBar(
        title: Text(l10n.profileStatistics),
        backgroundColor: context.uiColors.groupedBackground,
        automaticallyImplyLeading: false,
        leading: UiBarIconButton(
          icon: LucideIcons.arrowLeft,
          semanticLabel: l10n.back,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _StatisticsOverview(insights: insights),
          const SizedBox(height: UiSpacing.md),
          _HonorCard(honor: insights.honor),
          if (insights.rankedGames.isNotEmpty) ...[
            const SizedBox(height: UiSpacing.md),
            _MostPlayedSection(games: insights.rankedGames),
          ],
        ],
      ),
    );
  }
}

class _HonorCard extends StatelessWidget {
  const _HonorCard({required this.honor});

  final PlayHonor honor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.uiColors;
    final nextTier = honor.nextTier;
    final remainingDuration = _formatPlayTime(l10n, honor.remainingSeconds);
    final requirement = l10n.playHonorRequirement(honor, remainingDuration);

    return UiCard(
      key: const ValueKey<String>('statistics-honor-card'),
      borderRadius: UiRadius.brXl,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.award, size: 18, color: colors.brand),
              const SizedBox(width: UiSpacing.sm),
              Text(
                l10n.profileHonorTitle,
                style: context.uiType.footnote.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: UiSpacing.sm),
          Text(
            l10n.playHonorTier(honor.tier),
            key: const ValueKey<String>('statistics-honor-title'),
            style: context.uiType.title2.copyWith(color: colors.textPrimary),
          ),
          if (nextTier != null) ...[
            const SizedBox(height: 2),
            Text(
              l10n.profileHonorNext(l10n.playHonorTier(nextTier)),
              style: context.uiType.caption.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: UiSpacing.lg),
          ClipRRect(
            borderRadius: UiRadius.brPill,
            child: SizedBox(
              height: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: colors.surfaceElevated),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: honor.progress),
                    duration: UiDuration.slow,
                    curve: UiCurves.iosSpringOut,
                    builder: (context, value, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value.clamp(0, 1),
                      child: ColoredBox(
                        color: colors.brand.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: UiSpacing.sm),
          Text(
            requirement,
            key: const ValueKey<String>('statistics-honor-requirement'),
            style: context.uiType.footnote.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticsOverview extends StatelessWidget {
  const _StatisticsOverview({required this.insights});

  final PlayInsights insights;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.uiColors;

    return UiCard(
      key: const ValueKey<String>('statistics-overview-card'),
      borderRadius: UiRadius.brXxl,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.clock3, size: 17, color: colors.brand),
              const SizedBox(width: UiSpacing.sm),
              Text(
                l10n.profileLifetime,
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
            key: const ValueKey<String>('statistics-lifetime-total'),
            style: context.uiType.largeTitle.copyWith(
              color: colors.textPrimary,
              fontSize: 34,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: UiSpacing.xl),
          Row(
            children: [
              Text(
                l10n.profileLast7Days,
                style: context.uiType.footnote.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _formatPlayTime(l10n, insights.recentSeconds),
                key: const ValueKey<String>('statistics-week-total'),
                style: context.uiType.footnote.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: UiSpacing.md),
          _ActivityChart(days: insights.days),
          if (!insights.hasRecentActivity) ...[
            const SizedBox(height: UiSpacing.sm),
            Center(
              child: Text(
                l10n.profileTrackingHint,
                style: context.uiType.caption.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ),
          ],
          const SizedBox(height: UiSpacing.lg),
          Divider(height: 1, thickness: 0.5, color: colors.separator),
          const SizedBox(height: UiSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _OverviewMetric(
                  valueKey: const ValueKey<String>(
                    'statistics-active-days-value',
                  ),
                  value: insights.activeDays.toString(),
                  label: l10n.profileActiveDays,
                ),
              ),
              Expanded(
                child: _OverviewMetric(
                  valueKey: const ValueKey<String>(
                    'statistics-games-played-value',
                  ),
                  value: insights.playedGameCount.toString(),
                  label: l10n.profileGamesPlayed,
                ),
              ),
              Expanded(
                child: _OverviewMetric(
                  valueKey: const ValueKey<String>(
                    'statistics-average-session-value',
                  ),
                  value: _formatPlayTime(l10n, insights.averageSessionSeconds),
                  label: l10n.profileAverageSession,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.days});

  final List<DailyPlayActivity> days;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final l10n = AppLocalizations.of(context)!;
    final weekdays = MaterialLocalizations.of(context).narrowWeekdays;
    final maxSeconds = days.fold<int>(
      0,
      (largest, day) => day.seconds > largest ? day.seconds : largest,
    );

    return SizedBox(
      height: 88,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < days.length; index++)
            Expanded(
              child: Semantics(
                label:
                    '${weekdays[days[index].date.weekday % 7]} '
                    '${_formatPlayTime(l10n, days[index].seconds)}',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 64,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey<String>('statistics-bar-$index'),
                          tween: Tween<double>(
                            begin: 0,
                            end: maxSeconds == 0
                                ? 0
                                : days[index].seconds / maxSeconds,
                          ),
                          duration: UiDuration.slow,
                          curve: UiCurves.iosSpringOut,
                          builder: (context, value, _) => Container(
                            width: 9,
                            height: maxSeconds == 0 ? 4 : 4 + value * 60,
                            decoration: BoxDecoration(
                              color: days[index].seconds == 0
                                  ? colors.separator
                                  : colors.brand.withValues(
                                      alpha: days[index].isToday ? 1 : 0.55,
                                    ),
                              borderRadius: UiRadius.brPill,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      weekdays[days[index].date.weekday % 7],
                      style: context.uiType.caption.copyWith(
                        color: days[index].isToday
                            ? colors.textPrimary
                            : colors.textTertiary,
                        fontWeight: days[index].isToday
                            ? FontWeight.w600
                            : FontWeight.w400,
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

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.valueKey,
    required this.value,
    required this.label,
  });

  final Key valueKey;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          key: valueKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.uiType.headline.copyWith(
            color: context.uiColors.textPrimary,
          ),
        ),
        const SizedBox(height: UiSpacing.xs),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.uiType.caption.copyWith(
            color: context.uiColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MostPlayedSection extends StatelessWidget {
  const _MostPlayedSection({required this.games});

  final List<GameInfo> games;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxSeconds = games.first.playDurationSeconds ?? 0;

    return UiListSection(
      key: const ValueKey<String>('statistics-most-played'),
      header: l10n.profileTopGames,
      padding: EdgeInsets.zero,
      insetDividers: false,
      children: [
        for (var index = 0; index < games.length; index++)
          _MostPlayedRow(
            game: games[index],
            rank: index + 1,
            maxSeconds: maxSeconds,
          ),
      ],
    );
  }
}

class _MostPlayedRow extends StatelessWidget {
  const _MostPlayedRow({
    required this.game,
    required this.rank,
    required this.maxSeconds,
  });

  final GameInfo game;
  final int rank;
  final int maxSeconds;

  @override
  Widget build(BuildContext context) {
    final duration = game.playDurationSeconds ?? 0;
    final coverPath = game.coverPath;
    final hasCover = coverPath != null && File(coverPath).existsSync();
    final ratio = maxSeconds <= 0 ? 0.0 : duration / maxSeconds;

    return Padding(
      key: ValueKey<String>('statistics-game-row-$rank'),
      padding: const EdgeInsets.all(UiSpacing.md),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: UiGameCover(
                key: ValueKey<String>('statistics-game-cover-$rank'),
                image: hasCover ? FileImage(File(coverPath)) : null,
                borderRadius: UiRadius.brMd,
                semanticLabel: game.displayTitle,
              ),
            ),
          ),
          const SizedBox(width: UiSpacing.md),
          Expanded(
            child: SizedBox(
              height: 63,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        game.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiType.body.copyWith(
                          color: context.uiColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '#$rank',
                        style: context.uiType.caption.copyWith(
                          color: context.uiColors.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatPlayTime(
                          AppLocalizations.of(context)!,
                          duration,
                        ),
                        style: context.uiType.caption.copyWith(
                          color: context.uiColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: UiRadius.brPill,
                    child: SizedBox(
                      height: 3,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: context.uiColors.surfaceElevated),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: ratio.clamp(0, 1),
                            child: ColoredBox(
                              color: context.uiColors.brand.withValues(
                                alpha: 0.68,
                              ),
                            ),
                          ),
                        ],
                      ),
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

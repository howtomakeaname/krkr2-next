import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../models/game_info.dart';
import '../models/play_session.dart';
import '../ui/ui.dart';

/// “我的”页：游玩概览、常玩游戏与应用级入口。
class HomeProfileTab extends StatelessWidget {
  const HomeProfileTab({
    super.key,
    required this.games,
    required this.playSessions,
    required this.onOpenSettings,
    required this.onOpenHelp,
    required this.onOpenAbout,
    this.now,
  });

  final List<GameInfo> games;
  final List<PlaySession> playSessions;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHelp;
  final VoidCallback onOpenAbout;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final topPadding = MediaQuery.paddingOf(context).top;
    final insights = _PlayInsights.from(
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
          _PlayOverviewCard(insights: insights),
          if (insights.topGames.isNotEmpty) ...[
            const SizedBox(height: UiSpacing.md),
            _TopGamesSection(
              games: insights.topGames,
              maxSeconds: insights.topGames.first.playDurationSeconds ?? 0,
            ),
          ],
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

class _PlayOverviewCard extends StatelessWidget {
  const _PlayOverviewCard({required this.insights});

  final _PlayInsights insights;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.uiColors;

    return UiCard(
      key: const ValueKey<String>('profile-play-card'),
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
            key: const ValueKey<String>('profile-lifetime-total'),
            style: context.uiType.largeTitle.copyWith(
              color: colors.textPrimary,
              fontSize: 34,
              letterSpacing: -0.7,
            ),
          ),
          Text(
            l10n.profileLifetime,
            style: context.uiType.caption.copyWith(color: colors.textSecondary),
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
                key: const ValueKey<String>('profile-week-total'),
                style: context.uiType.footnote.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: UiSpacing.md),
          _ActivityChart(days: insights.days),
          if (insights.sessions.isEmpty) ...[
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
                  valueKey: const ValueKey<String>('profile-active-days-value'),
                  value: insights.activeDays.toString(),
                  label: l10n.profileActiveDays,
                ),
              ),
              Expanded(
                child: _OverviewMetric(
                  valueKey: const ValueKey<String>(
                    'profile-games-played-value',
                  ),
                  value: insights.playedGamePaths.length.toString(),
                  label: l10n.profileGamesPlayed,
                ),
              ),
              Expanded(
                child: _OverviewMetric(
                  valueKey: const ValueKey<String>(
                    'profile-average-session-value',
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

  final List<_DailyActivity> days;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final weekdays = MaterialLocalizations.of(context).narrowWeekdays;
    final maxSeconds = days.fold<int>(
      0,
      (largest, day) => math.max(largest, day.seconds),
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
                    '${_formatPlayTime(AppLocalizations.of(context)!, days[index].seconds)}',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 64,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey<String>('profile-activity-bar-$index'),
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
                            height: math.max(4, value * 64),
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

class _TopGamesSection extends StatelessWidget {
  const _TopGamesSection({required this.games, required this.maxSeconds});

  final List<GameInfo> games;
  final int maxSeconds;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return UiListSection(
      key: const ValueKey<String>('profile-top-games'),
      header: l10n.profileTopGames,
      padding: EdgeInsets.zero,
      insetDividers: false,
      children: [
        for (final game in games)
          _TopGameRow(game: game, maxSeconds: maxSeconds),
      ],
    );
  }
}

class _TopGameRow extends StatelessWidget {
  const _TopGameRow({required this.game, required this.maxSeconds});

  final GameInfo game;
  final int maxSeconds;

  @override
  Widget build(BuildContext context) {
    final duration = game.playDurationSeconds ?? 0;
    final coverPath = game.coverPath;
    final hasCover = coverPath != null && File(coverPath).existsSync();
    final ratio = maxSeconds <= 0 ? 0.0 : duration / maxSeconds;

    return Padding(
      padding: const EdgeInsets.all(UiSpacing.md),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 56,
            child: UiGameCover(
              image: hasCover ? FileImage(File(coverPath)) : null,
              borderRadius: UiRadius.brSm,
              semanticLabel: game.displayTitle,
            ),
          ),
          const SizedBox(width: UiSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        game.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiType.body.copyWith(
                          color: context.uiColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: UiSpacing.md),
                    Text(
                      _formatPlayTime(AppLocalizations.of(context)!, duration),
                      style: context.uiType.footnote.copyWith(
                        color: context.uiColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: UiSpacing.md),
                ClipRRect(
                  borderRadius: UiRadius.brPill,
                  child: SizedBox(
                    height: 4,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: context.uiColors.surfaceElevated),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: ratio.clamp(0, 1),
                          child: ColoredBox(
                            color: context.uiColors.brand.withValues(
                              alpha: 0.7,
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
        ],
      ),
    );
  }
}

class _PlayInsights {
  const _PlayInsights({
    required this.lifetimeSeconds,
    required this.recentSeconds,
    required this.averageSessionSeconds,
    required this.activeDays,
    required this.playedGamePaths,
    required this.days,
    required this.sessions,
    required this.topGames,
  });

  final int lifetimeSeconds;
  final int recentSeconds;
  final int averageSessionSeconds;
  final int activeDays;
  final Set<String> playedGamePaths;
  final List<_DailyActivity> days;
  final List<PlaySession> sessions;
  final List<GameInfo> topGames;

  factory _PlayInsights.from({
    required List<GameInfo> games,
    required List<PlaySession> sessions,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = today.subtract(const Duration(days: 6));
    final secondsByDay = <DateTime, int>{};
    final recentSessions = <PlaySession>[];
    for (final session in sessions) {
      final localEnd = session.endedAt.toLocal();
      final day = DateTime(localEnd.year, localEnd.month, localEnd.day);
      if (day.isBefore(firstDay) || day.isAfter(today)) continue;
      recentSessions.add(session);
      secondsByDay.update(
        day,
        (seconds) => seconds + session.durationSeconds,
        ifAbsent: () => session.durationSeconds,
      );
    }

    final days = [
      for (var index = 0; index < 7; index++)
        _DailyActivity(
          date: firstDay.add(Duration(days: index)),
          seconds: secondsByDay[firstDay.add(Duration(days: index))] ?? 0,
          isToday: index == 6,
        ),
    ];
    final recentSeconds = recentSessions.fold<int>(
      0,
      (sum, session) => sum + session.durationSeconds,
    );
    final topGames =
        games.where((game) => (game.playDurationSeconds ?? 0) > 0).toList()
          ..sort(
            (a, b) => (b.playDurationSeconds ?? 0).compareTo(
              a.playDurationSeconds ?? 0,
            ),
          );

    return _PlayInsights(
      lifetimeSeconds: games.fold<int>(
        0,
        (sum, game) => sum + (game.playDurationSeconds ?? 0),
      ),
      recentSeconds: recentSeconds,
      averageSessionSeconds: recentSessions.isEmpty
          ? 0
          : recentSeconds ~/ recentSessions.length,
      activeDays: secondsByDay.length,
      playedGamePaths: recentSessions
          .map((session) => session.gamePath)
          .toSet(),
      days: days,
      sessions: recentSessions,
      topGames: topGames.take(3).toList(growable: false),
    );
  }
}

class _DailyActivity {
  const _DailyActivity({
    required this.date,
    required this.seconds,
    required this.isToday,
  });

  final DateTime date;
  final int seconds;
  final bool isToday;
}

String _formatPlayTime(AppLocalizations l10n, int totalSeconds) {
  final totalMinutes = totalSeconds ~/ 60;
  if (totalMinutes < 60) return l10n.playTimeMinutes(totalMinutes);
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) return l10n.playTimeHours(hours);
  return l10n.playTimeHoursMinutes(hours, minutes);
}

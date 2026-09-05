import 'dart:math' as math;

import 'game_info.dart';
import 'play_session.dart';

enum PlayHonorTier {
  newcomer(minimumSeconds: 0, minimumGames: 0),
  storyTraveler(minimumSeconds: 1 * 3600, minimumGames: 1),
  immersedReader(minimumSeconds: 10 * 3600, minimumGames: 3),
  veteran(minimumSeconds: 30 * 3600, minimumGames: 6),
  collector(minimumSeconds: 100 * 3600, minimumGames: 12),
  curator(minimumSeconds: 300 * 3600, minimumGames: 24);

  const PlayHonorTier({
    required this.minimumSeconds,
    required this.minimumGames,
  });

  final int minimumSeconds;
  final int minimumGames;
}

class PlayHonor {
  const PlayHonor({
    required this.tier,
    required this.nextTier,
    required this.progress,
    required this.remainingSeconds,
    required this.remainingGames,
  });

  final PlayHonorTier tier;
  final PlayHonorTier? nextTier;
  final double progress;
  final int remainingSeconds;
  final int remainingGames;

  factory PlayHonor.from({
    required int lifetimeSeconds,
    required int playedGameCount,
  }) {
    var tier = PlayHonorTier.newcomer;
    for (final candidate in PlayHonorTier.values) {
      if (lifetimeSeconds >= candidate.minimumSeconds &&
          playedGameCount >= candidate.minimumGames) {
        tier = candidate;
      }
    }

    final nextIndex = tier.index + 1;
    if (nextIndex >= PlayHonorTier.values.length) {
      return PlayHonor(
        tier: tier,
        nextTier: null,
        progress: 1,
        remainingSeconds: 0,
        remainingGames: 0,
      );
    }

    final nextTier = PlayHonorTier.values[nextIndex];
    final timeSpan = nextTier.minimumSeconds - tier.minimumSeconds;
    final gameSpan = nextTier.minimumGames - tier.minimumGames;
    final timeProgress = timeSpan <= 0
        ? 1.0
        : ((lifetimeSeconds - tier.minimumSeconds) / timeSpan).clamp(0, 1);
    final gameProgress = gameSpan <= 0
        ? 1.0
        : ((playedGameCount - tier.minimumGames) / gameSpan).clamp(0, 1);

    return PlayHonor(
      tier: tier,
      nextTier: nextTier,
      // Both requirements carry equal weight, and progress reaches 100% only
      // when the time and library milestones have both been met.
      progress: (timeProgress + gameProgress) / 2,
      remainingSeconds: math.max(0, nextTier.minimumSeconds - lifetimeSeconds),
      remainingGames: math.max(0, nextTier.minimumGames - playedGameCount),
    );
  }
}

class DailyPlayActivity {
  const DailyPlayActivity({
    required this.date,
    required this.seconds,
    required this.isToday,
  });

  final DateTime date;
  final int seconds;
  final bool isToday;
}

/// A display-ready snapshot of the library's play history.
class PlayInsights {
  const PlayInsights({
    required this.lifetimeSeconds,
    required this.recentSeconds,
    required this.averageSessionSeconds,
    required this.activeDays,
    required this.playedGameCount,
    required this.days,
    required this.hasRecentActivity,
    required this.rankedGames,
  });

  final int lifetimeSeconds;
  final int recentSeconds;
  final int averageSessionSeconds;
  final int activeDays;
  final int playedGameCount;
  final List<DailyPlayActivity> days;
  final bool hasRecentActivity;
  final List<GameInfo> rankedGames;

  PlayHonor get honor => PlayHonor.from(
    lifetimeSeconds: lifetimeSeconds,
    playedGameCount: playedGameCount,
  );

  int get maxDailySeconds =>
      days.fold<int>(0, (largest, day) => math.max(largest, day.seconds));

  factory PlayInsights.from({
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
        DailyPlayActivity(
          date: firstDay.add(Duration(days: index)),
          seconds: secondsByDay[firstDay.add(Duration(days: index))] ?? 0,
          isToday: index == 6,
        ),
    ];
    final recentSeconds = recentSessions.fold<int>(
      0,
      (sum, session) => sum + session.durationSeconds,
    );
    final rankedGames =
        games.where((game) => (game.playDurationSeconds ?? 0) > 0).toList()
          ..sort(
            (a, b) => (b.playDurationSeconds ?? 0).compareTo(
              a.playDurationSeconds ?? 0,
            ),
          );

    return PlayInsights(
      lifetimeSeconds: games.fold<int>(
        0,
        (sum, game) => sum + (game.playDurationSeconds ?? 0),
      ),
      recentSeconds: recentSeconds,
      averageSessionSeconds: recentSessions.isEmpty
          ? 0
          : recentSeconds ~/ recentSessions.length,
      activeDays: secondsByDay.length,
      playedGameCount: rankedGames.length,
      days: days,
      hasRecentActivity: recentSessions.isNotEmpty,
      rankedGames: List<GameInfo>.unmodifiable(rankedGames),
    );
  }
}

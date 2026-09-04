import 'dart:math' as math;

import 'game_info.dart';
import 'play_session.dart';

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

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/models/game_info.dart';
import 'package:flutter_app/models/play_insights.dart';
import 'package:flutter_app/models/play_session.dart';

void main() {
  test('builds a seven-day snapshot without folding in older sessions', () {
    final now = DateTime(2026, 9, 5, 12);
    final games = [
      GameInfo(path: '/games/a', title: 'A', playDurationSeconds: 2 * 3600),
      GameInfo(path: '/games/b', title: 'B', playDurationSeconds: 3600),
      GameInfo(path: '/games/c', title: 'C'),
    ];
    final insights = PlayInsights.from(
      games: games,
      sessions: [
        PlaySession(
          id: 'today-a',
          gamePath: '/games/a',
          endedAt: DateTime(2026, 9, 5, 10),
          durationSeconds: 30 * 60,
        ),
        PlaySession(
          id: 'today-b',
          gamePath: '/games/b',
          endedAt: DateTime(2026, 9, 5, 11),
          durationSeconds: 15 * 60,
        ),
        PlaySession(
          id: 'older',
          gamePath: '/games/a',
          endedAt: DateTime(2026, 8, 28, 20),
          durationSeconds: 2 * 3600,
        ),
      ],
      now: now,
    );

    expect(insights.lifetimeSeconds, 3 * 3600);
    expect(insights.recentSeconds, 45 * 60);
    expect(insights.averageSessionSeconds, 22 * 60 + 30);
    expect(insights.activeDays, 1);
    expect(insights.playedGameCount, 2);
    expect(insights.days, hasLength(7));
    expect(insights.days.last.seconds, 45 * 60);
    expect(insights.days.last.isToday, isTrue);
    expect(insights.rankedGames.map((game) => game.path), [
      '/games/a',
      '/games/b',
    ]);
  });
}

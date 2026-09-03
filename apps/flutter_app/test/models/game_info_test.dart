import 'package:flutter_app/models/game_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads game JSON written before description and keywords existed', () {
    final game = GameInfo.fromJson({
      'path': '/games/legacy/data.xp3',
      'title': 'Legacy game',
      'developer': 'Legacy developer',
      'coverPath': '/covers/legacy.jpg',
      'playDurationSeconds': 42,
    });

    expect(game.title, 'Legacy game');
    expect(game.developer, 'Legacy developer');
    expect(game.description, isNull);
    expect(game.keywords, isEmpty);
  });

  test('round-trips scraped description and keywords', () {
    final original = GameInfo(
      path: '/games/test/data.xp3',
      title: 'Test game',
      description: 'A concise description.',
      keywords: const ['Romance', 'School life', 'Comedy'],
    );

    final decoded = GameInfo.listFromJsonString(
      GameInfo.listToJsonString([original]),
    ).single;

    expect(decoded.description, 'A concise description.');
    expect(decoded.keywords, ['Romance', 'School life', 'Comedy']);
  });

  test('ignores malformed optional metadata in otherwise valid old JSON', () {
    final malformedContainer = GameInfo.fromJson({
      'path': '/games/test/data.xp3',
      'description': 42,
      'keywords': 'Romance',
    });
    final mixedKeywords = GameInfo.fromJson({
      'path': '/games/other/data.xp3',
      'description': 'Description',
      'keywords': ['Romance', 42, null, 'Comedy'],
    });

    expect(malformedContainer.description, isNull);
    expect(malformedContainer.keywords, isEmpty);
    expect(mixedKeywords.description, 'Description');
    expect(mixedKeywords.keywords, ['Romance', 'Comedy']);
  });
}

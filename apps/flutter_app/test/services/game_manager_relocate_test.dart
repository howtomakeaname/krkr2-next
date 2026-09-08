import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/constants/prefs_keys.dart';
import 'package:flutter_app/models/game_info.dart';
import 'package:flutter_app/models/play_session.dart';
import 'package:flutter_app/services/game_manager.dart';

void main() {
  test(
    'relocate updates nested games, covers and history by boundary',
    () async {
      SharedPreferences.setMockInitialValues({
        'krkr2_game_list': GameInfo.listToJsonString([
          GameInfo(
            path: '/dl/app/games/星空',
            coverPath: '/dl/app/games/星空/cover.png',
            playDurationSeconds: 120,
            saveDirectoryName: '星空',
          ),
          GameInfo(
            path: '/dl/app/games/星空2',
            coverPath: '/docs/covers/other.png',
            playDurationSeconds: 10,
            saveDirectoryName: '星空2',
          ),
        ]),
        PrefsKeys.playSessionHistory: PlaySession.listToJsonString([
          PlaySession(
            id: 'a',
            gamePath: '/dl/app/games/星空',
            endedAt: DateTime(2026, 9, 1),
            durationSeconds: 30,
          ),
          PlaySession(
            id: 'b',
            gamePath: '/dl/app/games/星空2',
            endedAt: DateTime(2026, 9, 2),
            durationSeconds: 12,
          ),
        ]),
        PrefsKeys.pendingPlaySession: jsonEncode({
          'sessionId': 'pending',
          'path': '/dl/app/games/星空',
          'activeSeconds': 8,
        }),
      });

      final manager = GameManager();
      await manager.load();
      await manager.relocateBoundPaths('/dl/app/games/星空', '/dl/app/games/星空改');

      expect(manager.games[0].path, '/dl/app/games/星空改');
      expect(manager.games[0].coverPath, '/dl/app/games/星空改/cover.png');
      expect(manager.games[0].saveDirectoryName, '星空');
      expect(manager.games[0].playDurationSeconds, 120);
      expect(manager.games[1].path, '/dl/app/games/星空2');
      expect(manager.games[1].coverPath, '/docs/covers/other.png');
      expect(manager.playSessions[0].gamePath, '/dl/app/games/星空改');
      expect(manager.playSessions[1].gamePath, '/dl/app/games/星空2');

      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString(PrefsKeys.pendingPlaySession)!)['path'],
        '/dl/app/games/星空改',
      );
    },
  );

  test(
    'trashing a folder keeps history and can become available again',
    () async {
      SharedPreferences.setMockInitialValues({
        'krkr2_game_list': GameInfo.listToJsonString([
          GameInfo(path: '/games/one', playDurationSeconds: 40),
        ]),
        PrefsKeys.playSessionHistory: PlaySession.listToJsonString([
          PlaySession(
            id: 's',
            gamePath: '/games/one',
            endedAt: DateTime(2026, 9, 1),
            durationSeconds: 40,
          ),
        ]),
      });
      final manager = GameManager();
      await manager.load();
      await manager.markUnavailable('/games/one');
      expect(manager.games.single.available, isFalse);
      expect(manager.games.single.playDurationSeconds, 40);
      expect(manager.playSessions, hasLength(1));
      await manager.markAvailable('/games/one');
      expect(manager.games.single.available, isTrue);
      expect(manager.playSessions.single.gamePath, '/games/one');
    },
  );

  test('legacy entries pin a save directory from the original leaf', () {
    final game = GameInfo.fromJson({'path': '/dl/app/games/旧作/data.xp3'});
    expect(game.saveDirectoryName, '旧作');
    expect(game.available, isTrue);
  });
}

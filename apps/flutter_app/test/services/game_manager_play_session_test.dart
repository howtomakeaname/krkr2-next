import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/constants/prefs_keys.dart';
import 'package:flutter_app/models/game_info.dart';
import 'package:flutter_app/services/game_manager.dart';

void main() {
  const gamePath = '/games/test';

  test('persists a completed play session exactly once', () async {
    final game = GameInfo(path: gamePath, playDurationSeconds: 30);
    SharedPreferences.setMockInitialValues({
      'krkr2_game_list': GameInfo.listToJsonString([game]),
    });
    final endedAt = DateTime(2026, 9, 5, 20, 30);

    final manager = GameManager();
    await manager.load();
    await manager.recordPlaySession(
      gamePath,
      90,
      'session-1',
      endedAt: endedAt,
    );
    await manager.recordPlaySession(
      gamePath,
      90,
      'session-1',
      endedAt: endedAt,
    );

    expect(manager.games.single.playDurationSeconds, 120);
    expect(manager.playSessions, hasLength(1));
    expect(manager.playSessions.single.endedAt, endedAt);
    expect(manager.playSessions.single.durationSeconds, 90);

    final reloaded = GameManager();
    await reloaded.load();
    expect(reloaded.playSessions, hasLength(1));
    expect(reloaded.playSessions.single.id, 'session-1');
  });

  test('recovered pending time is included in session history', () async {
    final game = GameInfo(path: gamePath);
    SharedPreferences.setMockInitialValues({
      'krkr2_game_list': GameInfo.listToJsonString([game]),
      PrefsKeys.pendingPlaySession: jsonEncode({
        'version': 2,
        'sessionId': 'recovered-session',
        'path': gamePath,
        'activeSeconds': 75,
        'isRunning': false,
        'runningSinceEpochMs': 0,
      }),
    });

    final manager = GameManager();
    await manager.load();
    await manager.applyPendingPlaySession();

    expect(manager.games.single.playDurationSeconds, 75);
    expect(manager.playSessions.single.id, 'recovered-session');
    expect(manager.playSessions.single.durationSeconds, 75);
  });
}

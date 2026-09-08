import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/models/game_info.dart';
import 'package:flutter_app/services/archive_volumes.dart';
import 'package:flutter_app/services/file_manager_controller.dart';
import 'package:flutter_app/services/game_manager.dart';
import 'package:flutter_app/services/manager_scope.dart';
import 'package:flutter_app/services/manager_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory fixture;
  late FileManagerController controller;
  late GameManager games;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fixture = Directory(
      await Directory.systemTemp
          .createTemp('krkr-manager-ctl-')
          .then((dir) => dir.resolveSymbolicLinks()),
    );
    final root = await Directory(
      p.join(fixture.path, 'Downloads', ManagerScope.ohosAndroidAppId),
    ).create(recursive: true);
    await Directory(p.join(root.path, 'games')).create();
    await File(p.join(root.path, 'games', '星空', 'data.xp3')).create(recursive: true);
    games = GameManager();
    await games.load();
    await games.addGame(
      GameInfo(
        path: p.join(root.path, 'games', '星空'),
        playDurationSeconds: 90,
      ),
    );
    controller = FileManagerController(
      gameManager: games,
      storage: ManagerStorage(
        platform: 'linux',
        pickDirectory: () async => root.path,
      ),
    );
    await controller.authorize();
  });

  tearDown(() async {
    controller.dispose();
    if (await fixture.exists()) await fixture.delete(recursive: true);
  });

  test('rename updates library path and keeps the save folder name', () async {
    final source = p.join(controller.files!.gamesPath, '星空');
    await controller.rename(source, '星空改');
    expect(games.games.single.path, p.join(controller.files!.gamesPath, '星空改'));
    expect(games.games.single.saveDirectoryName, '星空');
    expect(games.games.single.available, isTrue);
  });

  test('trash keeps history and restore brings the folder back', () async {
    final source = p.join(controller.files!.gamesPath, '星空');
    controller.selected.add(source);
    await controller.trashSelected();
    expect(games.games.single.available, isFalse);
    expect(games.games.single.playDurationSeconds, 90);
    expect(await Directory(source).exists(), isFalse);
    await controller.restore(controller.trash.single);
    expect(games.games.single.available, isTrue);
    expect(await Directory(source).exists(), isTrue);
  });

  test('extract destination for a split archive is the group prefix', () {
    expect(
      ArchiveVolumes.extractFolderName('dlc.7z.001'),
      'dlc.7z',
    );
  });
}
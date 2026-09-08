import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_app/services/local_file_service.dart';

void main() {
  late Directory fixture;
  late Directory root;
  late LocalFileService service;
  final changes = <(String, String)>[];

  setUp(() async {
    // Canonicalize the test root because /var and /tmp are system aliases on macOS.
    final temporary = await Directory.systemTemp.createTemp(
      'krkr-file-service-',
    );
    fixture = Directory(await temporary.resolveSymbolicLinks());
    root = await Directory(
      p.join(fixture.path, 'Download', 'test.bundle'),
    ).create(recursive: true);
    await Directory(p.join(root.path, 'games')).create();
    changes.clear();
    service = LocalFileService(
      rootPath: root.path,
      onPathChanged: (a, b) async => changes.add((a, b)),
    );
  });

  tearDown(() async => fixture.delete(recursive: true));

  Future<File> write(String name, [String data = '内容 UTF-8 日本語 🐈']) async {
    final file = File(p.join(service.gamesPath, name));
    await file.parent.create(recursive: true);
    return file.writeAsString(data);
  }

  test('lists directories first and preserves Unicode names', () async {
    await write('中文 空格 🐈.txt');
    await write('日本語/first.ks');
    final entries = await service.list(service.gamesPath);
    expect(entries.map((e) => e.name), ['日本語', '中文 空格 🐈.txt']);
    expect(entries.first.isDirectory, isTrue);
  });

  test('rejects paths outside root and fixed root operations', () async {
    for (final source in [
      root.path,
      service.gamesPath,
      fixture.path,
      p.join(root.path, '..', 'outside'),
    ]) {
      await expectLater(
        service.trash(source),
        throwsA(isA<FileOperationException>()),
      );
    }
    await expectLater(
      service.list(fixture.path),
      throwsA(isA<FileOperationException>()),
    );
  });

  test('rejects unsafe names but accepts UTF-8', () async {
    for (final name in [
      '..',
      '../x',
      'a/b',
      r'a\b',
      'bad\u0000',
      '.krkr-manager',
      'a.',
    ]) {
      expect(
        () => LocalFileService.validateName(name),
        throwsA(isA<FileOperationException>()),
      );
    }
    await service.createDirectory(service.gamesPath, '日本語 中文 🐈');
    expect(
      await Directory(p.join(service.gamesPath, '日本語 中文 🐈')).exists(),
      isTrue,
    );
  });

  test('rename and move notify path changes without changing bytes', () async {
    final source = await write('old.txt');
    await service.rename(source.path, '中文.txt');
    final renamed = p.join(service.gamesPath, '中文.txt');
    final moved = p.join(root.path, '中文.txt');
    await service.move(renamed, moved);
    expect(await File(moved).readAsString(), '内容 UTF-8 日本語 🐈');
    expect(changes, [(source.path, renamed), (renamed, moved)]);
  });

  test(
    'refuses collisions without overwriting and leaves source intact',
    () async {
      final a = await write('A.txt', 'first');
      await write('B.txt', 'second');
      await expectLater(
        service.rename(a.path, 'b.txt'),
        throwsA(isA<FileOperationException>()),
      );
      expect(await a.readAsString(), 'first');
      expect(
        await File(p.join(service.gamesPath, 'B.txt')).readAsString(),
        'second',
      );
    },
  );

  test('blocks link ancestors and linked children during copy', () async {
    final outside = await Directory(p.join(fixture.path, 'outside')).create();
    final secret = await File(
      p.join(outside.path, 'keep.txt'),
    ).writeAsString('keep');
    final link = Link(p.join(service.gamesPath, 'link'));
    await link.create(outside.path);
    await expectLater(
      service.list(link.path),
      throwsA(isA<FileOperationException>()),
    );
    await expectLater(
      service.trash(p.join(link.path, 'keep.txt')),
      throwsA(isA<FileOperationException>()),
    );
    await write('folder/file.txt');
    await Link(
      p.join(service.gamesPath, 'folder', 'linked'),
    ).create(outside.path);
    await expectLater(
      service.copy(
        p.join(service.gamesPath, 'folder'),
        p.join(service.gamesPath, 'copy'),
        FileTask(),
      ),
      throwsA(isA<FileOperationException>()),
    );
    expect(await secret.readAsString(), 'keep');
    expect(
      await Directory(p.join(service.gamesPath, 'copy')).exists(),
      isFalse,
    );
  });

  test(
    'recursive copy preserves bytes and publishes only completed output',
    () async {
      final file = await write('原目录/日本語 🐈.txt');
      final source = file.parent.path;
      final destination = p.join(service.gamesPath, '副本');
      final task = FileTask();
      await service.copy(source, destination, task);
      expect(
        await File(p.join(destination, p.basename(file.path))).readAsBytes(),
        await file.readAsBytes(),
      );
      expect(task.completed, task.total);
      expect(changes, isEmpty);
      expect(
        (await service.list(
          root.path,
        )).any((e) => e.name == LocalFileService.privateName),
        isFalse,
      );
    },
  );

  test('cancelled copy removes only its temporary output', () async {
    final file = await write('large.bin', 'a' * 200000);
    final task = FileTask();
    task.onProgress = () => task.cancelled = true;
    final destination = p.join(service.gamesPath, 'copy.bin');
    await expectLater(
      service.copy(file.path, destination, task),
      throwsA(isA<FileOperationException>()),
    );
    expect(await File(destination).exists(), isFalse);
    expect(await file.length(), 200000);
    expect(
      await Directory(
        p.join(root.path, LocalFileService.privateName, 'tasks'),
      ).list().length,
      0,
    );
  });

  test('rejects copy and move into a descendant', () async {
    await write('folder/keep.txt');
    final source = p.join(service.gamesPath, 'folder');
    await expectLater(
      service.move(source, p.join(source, 'child')),
      throwsA(isA<FileOperationException>()),
    );
    await expectLater(
      service.copy(source, p.join(source, 'child'), FileTask()),
      throwsA(isA<FileOperationException>()),
    );
  });

  test('trash survives service recreation and restores Unicode file', () async {
    final file = await write('中文 🐈.txt');
    final item = await service.trash(file.path);
    expect(await file.exists(), isFalse);
    final recreated = LocalFileService(rootPath: root.path);
    final listed = await recreated.deletedFiles();
    expect(listed.single.id, item.id);
    expect(listed.single.originalPath, file.path);
    await recreated.restore(listed.single);
    expect(await file.readAsString(), '内容 UTF-8 日本語 🐈');
    expect(await recreated.deletedFiles(), isEmpty);
  });

  test('restore never overwrites a replacement', () async {
    final file = await write('game.txt', 'original');
    final item = await service.trash(file.path);
    await file.writeAsString('replacement');
    await expectLater(
      service.restore(item),
      throwsA(isA<FileOperationException>()),
    );
    expect(await file.readAsString(), 'replacement');
    expect((await service.deletedFiles()).single.id, item.id);
  });

  test('permanent delete affects only selected trash entry', () async {
    final a = await service.trash((await write('a.txt')).path);
    final b = await service.trash((await write('b.txt')).path);
    await service.permanentlyDelete(a);
    expect((await service.deletedFiles()).single.id, b.id);
    await expectLater(
      service.permanentlyDelete(
        DeletedFile(
          id: '../../',
          originalPath: fixture.path,
          deletedAt: DateTime.now(),
        ),
      ),
      throwsA(isA<FileOperationException>()),
    );
    expect(await Directory(service.gamesPath).exists(), isTrue);
  });

  test('metadata failure rolls disk rename back', () async {
    final file = await write('original.txt');
    final failing = LocalFileService(
      rootPath: root.path,
      onPathChanged: (_, _) async => throw StateError('storage failure'),
    );
    await expectLater(
      failing.rename(file.path, 'changed.txt'),
      throwsStateError,
    );
    expect(await file.exists(), isTrue);
    expect(
      await File(p.join(service.gamesPath, 'changed.txt')).exists(),
      isFalse,
    );
  });

  test(
    'failed extraction leaves no published folder or source changes',
    () async {
      final source = await write('包.zip', 'archive');
      final destination = p.join(service.gamesPath, '包');
      await expectLater(
        service.extract(destination, (output) async {
          await File(p.join(output, 'partial.txt')).writeAsString('partial');
          throw const FileOperationException('密码错误');
        }),
        throwsA(isA<FileOperationException>()),
      );
      expect(await Directory(destination).exists(), isFalse);
      expect(await source.readAsString(), 'archive');
    },
  );

  test('completed extraction atomically publishes a new directory', () async {
    final destination = p.join(service.gamesPath, '游戏');
    await service.extract(destination, (output) async {
      expect(await Directory(destination).exists(), isFalse);
      await File(p.join(output, '日本語.ks')).writeAsString('脚本');
    });
    expect(await File(p.join(destination, '日本語.ks')).readAsString(), '脚本');
  });
}

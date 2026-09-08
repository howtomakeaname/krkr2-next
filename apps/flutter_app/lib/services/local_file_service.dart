import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'file_operation_error.dart';
export 'file_operation_error.dart';

class FileTask {
  bool cancelled = false;
  int completed = 0;
  int total = 0;
  String currentName = '';
  void Function()? onProgress;

  void check() {
    if (cancelled) throw const FileOperationException(FileErrorCode.cancelled);
  }

  void report() => onProgress?.call();
}

class LocalFileEntry {
  const LocalFileEntry(this.path, this.stat);
  final String path;
  final FileStat stat;
  String get name => p.basename(path);
  bool get isDirectory => stat.type == FileSystemEntityType.directory;
}

class DeletedFile {
  const DeletedFile({
    required this.id,
    required this.originalPath,
    required this.deletedAt,
  });
  final String id;
  final String originalPath;
  final DateTime deletedAt;
}

/// A single-writer file service. No operation may leave [rootPath], follow a
/// symbolic link or overwrite an existing item. Private work is excluded from
/// directory listings and game discovery, including while a copy is incomplete.
class LocalFileService {
  LocalFileService({required String rootPath, this.onPathChanged})
    : rootPath = p.normalize(p.absolute(rootPath));

  static const privateName = '.krkr-manager';
  final String rootPath;
  final Future<void> Function(String from, String to)? onPathChanged;
  bool _busy = false;
  bool get isBusy => _busy;
  String get gamesPath => p.join(rootPath, 'games');
  String get _privatePath => p.join(rootPath, privateName);

  Future<T> _exclusive<T>(Future<T> Function() operation) async {
    if (_busy) throw const FileOperationException(FileErrorCode.busy);
    _busy = true;
    try {
      return await operation();
    } finally {
      _busy = false;
    }
  }

  static bool isPrivatePath(String path) =>
      p.split(path).any((part) => part.toLowerCase() == privateName);

  static void validateName(String name) {
    if (name.trim().isEmpty ||
        name == '.' ||
        name == '..' ||
        name.endsWith('.') ||
        name.endsWith(' ') ||
        name.toLowerCase() == privateName ||
        RegExp(r'[\x00-\x1f/\\:*?"<>|]').hasMatch(name) ||
        utf8.encode(name).length > 255) {
      throw const FileOperationException(FileErrorCode.invalidName);
    }
  }

  Future<String> validatePath(
    String input, {
    bool internal = false,
    bool mutate = false,
  }) async {
    final path = p.normalize(p.absolute(input));
    if (path != rootPath && !p.isWithin(rootPath, path)) {
      throw const FileOperationException(FileErrorCode.outsideRoot);
    }
    if (!internal && isPrivatePath(p.relative(path, from: rootPath))) {
      throw const FileOperationException(FileErrorCode.protectedDirectory);
    }
    if (mutate &&
        (path == rootPath || path.toLowerCase() == gamesPath.toLowerCase())) {
      throw const FileOperationException(FileErrorCode.protectedDirectory);
    }
    // Check each component, not just the last one: a link in an ancestor can
    // otherwise redirect a perfectly ordinary-looking child outside the root.
    String cursor = p.rootPrefix(path);
    for (final part in p.split(path).skip(1)) {
      cursor = p.join(cursor, part);
      if (await FileSystemEntity.type(cursor, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const FileOperationException(FileErrorCode.unsupportedLink);
      }
    }
    return path;
  }

  Future<List<LocalFileEntry>> list(String directory) async {
    final path = await validatePath(directory);
    final result = <LocalFileEntry>[];
    await for (final entry in Directory(path).list(followLinks: false)) {
      if (p.basename(entry.path).toLowerCase() == privateName) continue;
      if (await FileSystemEntity.type(entry.path, followLinks: false) ==
          FileSystemEntityType.link) {
        continue;
      }
      result.add(LocalFileEntry(entry.path, await entry.stat()));
    }
    result.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return result;
  }

  Future<void> _requireVacant(
    String destination, {
    bool internal = false,
  }) async {
    await validatePath(destination, internal: internal);
    final parent = Directory(p.dirname(destination));
    if (!await parent.exists()) {
      throw const FileOperationException(FileErrorCode.notFound);
    }
    // Download is case-insensitive. Keep the same collision policy in tests
    // and on other hosts, including for an empty destination directory.
    await for (final entry in parent.list(followLinks: false)) {
      if (p.basename(entry.path).toLowerCase() ==
          p.basename(destination).toLowerCase()) {
        throw const FileOperationException(FileErrorCode.conflict);
      }
    }
  }

  Future<void> createDirectory(String parent, String name) =>
      _exclusive(() async {
        validateName(name);
        await validatePath(parent);
        final destination = p.join(parent, name);
        await _requireVacant(destination);
        await Directory(destination).create();
      });

  Future<void> rename(String source, String name) {
    validateName(name);
    return move(source, p.join(p.dirname(source), name));
  }

  Future<void> move(String source, String destination) => _exclusive(() async {
    final from = await validatePath(source, mutate: true);
    final to = await validatePath(destination);
    if (from == to || p.isWithin(from, to)) {
      throw const FileOperationException(FileErrorCode.recursiveTarget);
    }
    await _requireVacant(to);
    await _relocate(from, to);
  });

  Future<void> _relocate(String from, String to, {bool notify = true}) async {
    await _renameEntity(from, to);
    if (!notify) return;
    try {
      await onPathChanged?.call(from, to);
    } catch (_) {
      // Metadata must not silently point at a path that no longer exists.
      await _renameEntity(to, from);
      rethrow;
    }
  }

  Future<void> _renameEntity(String from, String to) async {
    await validatePath(from, internal: true);
    await validatePath(to, internal: true);
    if (await FileSystemEntity.type(from, followLinks: false) ==
        FileSystemEntityType.directory) {
      await Directory(from).rename(to);
    } else {
      await File(from).rename(to);
    }
  }

  String _newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<Directory> _workspace(String kind) async {
    final path = p.join(_privatePath, kind, _newId());
    await validatePath(path, internal: true);
    return Directory(path).create(recursive: true);
  }

  Future<void> copy(String source, String destination, FileTask task) =>
      _exclusive(() async {
        final from = await validatePath(source, mutate: true);
        final to = await validatePath(destination);
        if (from == to || p.isWithin(from, to)) {
          throw const FileOperationException(FileErrorCode.recursiveTarget);
        }
        await _requireVacant(to);
        final work = await _workspace('tasks');
        try {
          task.total = await _measure(from, task);
          await _copyEntity(from, p.join(work.path, 'item'), task);
          task.check();
          await _requireVacant(to);
          await _renameEntity(p.join(work.path, 'item'), to);
        } finally {
          await _deletePrivateWorkspace(work.path);
        }
      });

  Future<int> _measure(String path, FileTask task) async {
    task.check();
    await validatePath(path);
    if (await FileSystemEntity.type(path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return (await File(path).stat()).size;
    }
    var bytes = 0;
    await for (final entry in Directory(path).list(followLinks: false)) {
      bytes += await _measure(entry.path, task);
    }
    return bytes;
  }

  Future<void> _copyEntity(String from, String to, FileTask task) async {
    task.check();
    await validatePath(from);
    await validatePath(to, internal: true);
    if (await FileSystemEntity.type(from, followLinks: false) ==
        FileSystemEntityType.directory) {
      await Directory(to).create();
      await for (final entry in Directory(from).list(followLinks: false)) {
        await _copyEntity(entry.path, p.join(to, p.basename(entry.path)), task);
      }
      return;
    }
    task.currentName = p.basename(from);
    final output = await File(to).open(mode: FileMode.writeOnly);
    try {
      await for (final bytes in File(from).openRead()) {
        task.check();
        await output.writeFrom(bytes);
        task.completed += bytes.length;
        task.report();
      }
      await output.flush();
    } finally {
      await output.close();
    }
  }

  Future<DeletedFile> trash(String source) => _exclusive(() async {
    final from = await validatePath(source, mutate: true);
    final work = await _workspace('trash');
    final item = DeletedFile(
      id: p.basename(work.path),
      originalPath: from,
      deletedAt: DateTime.now(),
    );
    final manifest = File(p.join(work.path, 'entry.json'));
    await manifest.writeAsString(
      jsonEncode({
        'path': p.relative(from, from: rootPath),
        'deletedAt': item.deletedAt.toIso8601String(),
      }),
      flush: true,
    );
    try {
      // Trash is not a library relocate. GameManager keeps the original
      // path and marks the entry unavailable so history is not rewritten
      // into `.krkr-manager/trash`.
      await _relocate(from, p.join(work.path, 'item'), notify: false);
    } catch (_) {
      await _deletePrivateWorkspace(work.path);
      rethrow;
    }
    return item;
  });

  String _trashWorkspace(String id) {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(id)) {
      throw const FileOperationException(FileErrorCode.trashCorrupt);
    }
    return p.join(_privatePath, 'trash', id);
  }

  Future<List<DeletedFile>> deletedFiles() async {
    final trashPath = p.join(_privatePath, 'trash');
    await validatePath(trashPath, internal: true);
    if (!await Directory(trashPath).exists()) return [];
    final items = <DeletedFile>[];
    await for (final work in Directory(trashPath).list(followLinks: false)) {
      if (work is! Directory ||
          !RegExp(r'^[0-9a-f]{32}$').hasMatch(p.basename(work.path))) {
        continue;
      }
      await validatePath(work.path, internal: true);
      final manifest = p.join(work.path, 'entry.json');
      await validatePath(manifest, internal: true);
      final payload = p.join(work.path, 'item');
      await validatePath(payload, internal: true);
      if (await FileSystemEntity.type(payload, followLinks: false) ==
          FileSystemEntityType.notFound) {
        continue;
      }
      final data =
          jsonDecode(await File(manifest).readAsString())
              as Map<String, dynamic>;
      final relative = data['path'] as String;
      if (p.isAbsolute(relative)) {
        throw const FileOperationException(FileErrorCode.trashCorrupt);
      }
      final original = await validatePath(
        p.join(rootPath, relative),
        mutate: true,
      );
      items.add(
        DeletedFile(
          id: p.basename(work.path),
          originalPath: original,
          deletedAt: DateTime.parse(data['deletedAt'] as String),
        ),
      );
    }
    items.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return items;
  }

  Future<void> restore(DeletedFile item) => _exclusive(() async {
    // Resolve the persisted record again; never trust a caller-supplied target.
    final persisted = (await deletedFiles()).firstWhere((e) => e.id == item.id);
    final to = await validatePath(persisted.originalPath, mutate: true);
    await _requireVacant(to);
    final work = _trashWorkspace(item.id);
    await _relocate(p.join(work, 'item'), to);
    await _deletePrivateWorkspace(work);
  });

  Future<void> permanentlyDelete(DeletedFile item) => _exclusive(() async {
    if (!(await deletedFiles()).any((e) => e.id == item.id)) {
      throw const FileOperationException(FileErrorCode.notFound);
    }
    await _deletePrivateWorkspace(_trashWorkspace(item.id));
  });

  Future<void> _deletePrivateWorkspace(String path) async {
    final normalized = await validatePath(path, internal: true);
    final rel = p.split(p.relative(normalized, from: _privatePath));
    if (rel.length != 2 ||
        !{'trash', 'tasks'}.contains(rel.first) ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(rel.last)) {
      throw const FileOperationException(FileErrorCode.outsideRoot);
    }
    // Directory.delete does not follow child links. The workspace itself has
    // already been checked and is always a single generated task directory.
    if (await Directory(normalized).exists()) {
      await Directory(normalized).delete(recursive: true);
    }
  }

  /// Native extraction writes only into a newly created task directory. Publish
  /// it after success so the library never discovers a partially unpacked game.
  Future<void> extract(
    String destination,
    Future<void> Function(String output) unpack,
  ) => _exclusive(() async {
    await _requireVacant(destination);
    final work = await _workspace('tasks');
    final output = await Directory(p.join(work.path, 'item')).create();
    try {
      await unpack(output.path);
      await _requireVacant(destination);
      await _renameEntity(output.path, destination);
    } finally {
      await _deletePrivateWorkspace(work.path);
    }
  });
}

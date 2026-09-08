import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'archive_extractor.dart';
import 'archive_volumes.dart';
import 'engine_runtime_guard.dart';
import 'file_operation_error.dart';
import 'game_manager.dart';
import 'local_file_service.dart';
import 'manager_scope.dart';
import 'manager_storage.dart';

/// Coordinates grant, file tasks, library relocate and engine safety.
class FileManagerController extends ChangeNotifier {
  FileManagerController({
    required this.gameManager,
    ManagerStorage? storage,
    ArchiveExtractor? extractor,
    EngineRuntimeGuard? runtimeGuard,
  }) : storage = storage ?? ManagerStorage(),
       extractor = extractor ?? ArchiveExtractor(),
       runtimeGuard = runtimeGuard ?? EngineRuntimeGuard.instance;

  final GameManager gameManager;
  final ManagerStorage storage;
  final ArchiveExtractor extractor;
  final EngineRuntimeGuard runtimeGuard;

  ManagerGrant? grant;
  LocalFileService? files;
  String currentPath = '';
  List<LocalFileEntry> entries = const [];
  List<DeletedFile> trash = const [];
  final selected = <String>{};
  bool selecting = false;
  bool loading = false;
  bool get isBusy => files?.isBusy ?? false;
  bool get blocksLibraryScan => isBusy;
  FileTask? task;
  FileOperationException? lastError;

  Future<void> load() async {
    loading = true;
    lastError = null;
    notifyListeners();
    try {
      grant = await storage.currentGrant();
      _bindService();
      if (files != null) {
        currentPath = files!.gamesPath;
        await Directory(currentPath).create(recursive: true);
        await refresh();
      }
    } on FileOperationException catch (error) {
      lastError = error;
    } catch (error) {
      lastError = FileOperationException.from(error);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> authorize() async {
    lastError = null;
    notifyListeners();
    try {
      grant = await storage.authorize();
      _bindService();
      currentPath = files!.gamesPath;
      await Directory(currentPath).create(recursive: true);
      await refresh();
    } on FileOperationException catch (error) {
      if (error.code == FileErrorCode.cancelled) return;
      lastError = error;
    } catch (error) {
      lastError = FileOperationException.from(error);
    } finally {
      notifyListeners();
    }
  }

  void _bindService() {
    final root = grant;
    files = root == null
        ? null
        : LocalFileService(
            rootPath: root.rootPath,
            onPathChanged: gameManager.relocateBoundPaths,
          );
  }

  Future<void> refresh() async {
    final service = files;
    if (service == null) return;
    entries = await service.list(currentPath);
    trash = await service.deletedFiles();
    selected.removeWhere(
      (path) => entries.every((entry) => entry.path != path),
    );
    notifyListeners();
  }

  Future<void> open(String path) async {
    if (selecting) {
      toggle(path);
      return;
    }
    currentPath = path;
    selected.clear();
    await refresh();
  }

  Future<void> openParent() async {
    final service = files;
    if (service == null) return;
    if (p.equals(currentPath, service.rootPath)) return;
    currentPath = p.dirname(currentPath);
    selected.clear();
    await refresh();
  }

  void toggleSelecting(bool value) {
    selecting = value;
    if (!value) selected.clear();
    notifyListeners();
  }

  void toggle(String path) {
    if (!selected.add(path)) selected.remove(path);
    notifyListeners();
  }

  void selectAll() {
    selected
      ..clear()
      ..addAll(entries.map((entry) => entry.path));
    notifyListeners();
  }

  List<String> get _targets =>
      selected.isEmpty ? const [] : selected.toList(growable: false);

  Future<void> createFolder(String name) =>
      _run(() => files!.createDirectory(currentPath, name));

  Future<void> rename(String source, String name) async {
    await _run(() async {
      final group = _groupFor(source);
      if (group.length == 1) {
        await files!.rename(source, name);
        return;
      }
      final fromName = p.basename(source);
      for (final member in group) {
        await files!.rename(
          member,
          ArchiveVolumes.renamedMember(p.basename(member), fromName, name),
        );
      }
    });
  }

  Future<void> copyTo(String destinationDir) => _run(() async {
    final progress = _beginTask();
    for (final source in _expand(_targets)) {
      await files!.copy(
        source,
        p.join(destinationDir, p.basename(source)),
        progress,
      );
    }
  });

  Future<void> moveTo(String destinationDir) => _run(() async {
    for (final source in _expand(_targets)) {
      await files!.move(source, p.join(destinationDir, p.basename(source)));
    }
  });

  Future<void> trashSelected() => _run(() async {
    for (final source in _expand(_targets)) {
      await files!.trash(source);
      await gameManager.markUnavailable(source);
    }
  });

  Future<void> restore(DeletedFile item) => _run(() async {
    await files!.restore(item);
    await gameManager.markAvailable(item.originalPath);
  });

  Future<void> permanentlyDelete(DeletedFile item) =>
      _run(() => files!.permanentlyDelete(item));

  Future<void> extract(
    String source, {
    String? password,
    int legacyCodepage = 65001,
  }) {
    final destination = p.join(
      p.dirname(source),
      ArchiveVolumes.extractFolderName(p.basename(source)),
    );
    return _run(() async {
      await runtimeGuard.prepareMutation(source);
      await files!.extract(
        destination,
        (output) => extractor.unpack(
          root: files!.rootPath,
          source: source,
          destination: output,
          password: password,
          legacyCodepage: legacyCodepage,
          task: _beginTask(),
        ),
      );
    });
  }

  void cancelTask() {
    task?.cancelled = true;
  }

  bool get canMutateCurrent =>
      files != null &&
      !p.equals(currentPath, files!.rootPath) &&
      !p.equals(currentPath.toLowerCase(), files!.gamesPath.toLowerCase());

  List<String> breadcrumbLabels() {
    final service = files;
    if (service == null) return const [];
    final relative = p.relative(currentPath, from: service.rootPath);
    if (relative == '.') return const [''];
    return ['', ...p.split(relative)];
  }

  Future<void> openBreadcrumb(int index) async {
    final service = files;
    if (service == null) return;
    if (index <= 0) {
      currentPath = service.rootPath;
    } else {
      currentPath = p.joinAll([
        service.rootPath,
        ...breadcrumbLabels().skip(1).take(index),
      ]);
    }
    selected.clear();
    await refresh();
  }

  bool looksLikeArchive(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.zip') ||
        lower.endsWith('.7z') ||
        lower.endsWith('.rar') ||
        lower.endsWith('.tar') ||
        lower.endsWith('.gz') ||
        lower.endsWith('.bz2') ||
        lower.endsWith('.xz') ||
        lower.endsWith('.zst') ||
        ArchiveVolumes.isVolume(name);
  }

  Future<void> _run(Future<void> Function() operation) async {
    lastError = null;
    notifyListeners();
    try {
      for (final path in {..._targets, currentPath}) {
        await runtimeGuard.prepareMutation(path);
      }
      await operation();
      selected.clear();
      selecting = false;
      await refresh();
    } on FileOperationException catch (error) {
      if (error.code != FileErrorCode.cancelled) lastError = error;
    } catch (error) {
      lastError = FileOperationException.from(error);
    } finally {
      task = null;
      notifyListeners();
    }
  }

  FileTask _beginTask() {
    final next = FileTask();
    next.onProgress = notifyListeners;
    task = next;
    return next;
  }

  List<String> _groupFor(String path) {
    return ArchiveVolumes.members(
      p.basename(path),
      entries.map((entry) => entry.name),
    ).map((name) => p.join(p.dirname(path), name)).toList();
  }

  List<String> _expand(List<String> paths) {
    final seen = <String>{};
    for (final path in paths) {
      seen.addAll(_groupFor(path));
    }
    return seen.toList();
  }
}

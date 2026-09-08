import 'package:path/path.dart' as p;

import 'file_operation_error.dart';

/// File operations must not run against a live or parked engine session.
///
/// The game page parks its runtime when it pops, so "the game screen is
/// closed" is not enough. Callers ask this guard to release a parked session
/// and wait for destroy before touching those files.
class EngineRuntimeGuard {
  EngineRuntimeGuard({
    bool Function()? isPageActive,
    String? Function()? pagePath,
    String? Function()? parkedPath,
    Future<void> Function()? releaseParked,
  }) : _isPageActive = isPageActive,
       _pagePath = pagePath,
       _parkedPath = parkedPath,
       _releaseParked = releaseParked;

  static final EngineRuntimeGuard instance = EngineRuntimeGuard(
    isPageActive: () => GameRuntimeBinding.pageActive,
    pagePath: () => GameRuntimeBinding.pagePath,
    parkedPath: () => GameRuntimeBinding.parkedPath,
    releaseParked: GameRuntimeBinding.releaseParked,
  );

  final bool Function()? _isPageActive;
  final String? Function()? _pagePath;
  final String? Function()? _parkedPath;
  final Future<void> Function()? _releaseParked;

  bool overlaps(String path) {
    return _overlaps(path, _pagePath?.call()) ||
        _overlaps(path, _parkedPath?.call());
  }

  /// Throws [FileErrorCode.gameRunning] when the game page still owns the
  /// path. A parked session is destroyed and awaited first.
  Future<void> prepareMutation(String path) async {
    if ((_isPageActive?.call() ?? false) &&
        _overlaps(path, _pagePath?.call())) {
      throw const FileOperationException(FileErrorCode.gameRunning);
    }
    if (_overlaps(path, _parkedPath?.call())) {
      await _releaseParked?.call();
    }
    if (_overlaps(path, _parkedPath?.call()) ||
        ((_isPageActive?.call() ?? false) &&
            _overlaps(path, _pagePath?.call()))) {
      throw const FileOperationException(FileErrorCode.gameRunning);
    }
  }

  static bool _overlaps(String path, String? target) {
    if (target == null || target.isEmpty) return false;
    final left = p.normalize(path);
    final right = p.normalize(target);
    return left == right || p.isWithin(left, right) || p.isWithin(right, left);
  }
}

/// Process-wide registration used by [EngineRuntimeGuard.instance].
///
/// GamePage writes these fields; file management only reads them through the
/// guard so callers cannot clear a live runtime by assignment.
class GameRuntimeBinding {
  GameRuntimeBinding._();

  static bool pageActive = false;
  static String? pagePath;
  static String? parkedPath;
  static Future<void> Function()? _releaseParked;

  static void enter(String path) {
    pageActive = true;
    pagePath = path;
  }

  static void leave(String path) {
    if (pagePath == path) {
      pageActive = false;
      pagePath = null;
    }
  }

  static void park(String path, Future<void> Function() release) {
    parkedPath = path;
    _releaseParked = release;
  }

  static void clearParked(String path) {
    if (parkedPath == path) {
      parkedPath = null;
      _releaseParked = null;
    }
  }

  static Future<void> releaseParked() async {
    final release = _releaseParked;
    _releaseParked = null;
    if (release != null) await release();
  }
}

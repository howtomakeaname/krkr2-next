import 'dart:io';

/// Which native runtime a library entry is launched with.
///
/// The C bridge (`libengine_api`) picks the backend from the path by itself
/// (`engine=auto`); the app keeps the same classification so it can show
/// engine badges, run engine-specific preflight checks and pass an explicit
/// `engine` option when the user overrides the detection.
enum GameEngine {
  /// KiriKiri2 / KAG (`.xp3` archives, `startup.tjs` directories).
  krkr2,

  /// Artemis Engine (`.pfs` pack chains, `system.ini` + `system/first.iet`).
  artemis;

  /// Stable identifier persisted in the game list / sent to the bridge.
  String get id => switch (this) {
        GameEngine.krkr2 => 'krkr2',
        GameEngine.artemis => 'artemis',
      };

  /// Short display label (engine names are proper nouns; not localized).
  String get label => switch (this) {
        GameEngine.krkr2 => 'KiriKiri2',
        GameEngine.artemis => 'Artemis',
      };

  static GameEngine? fromId(String? id) {
    switch (id) {
      case 'krkr2':
        return GameEngine.krkr2;
      case 'artemis':
        return GameEngine.artemis;
      default:
        return null;
    }
  }

  /// True for `<name>.pfs` (base pack). Patch volumes `<name>.pfs.000` are
  /// chained by the engine and never registered on their own.
  static bool isPfsPack(String path) => path.toLowerCase().endsWith('.pfs');

  /// True for any Artemis pack volume, base or patch (`.pfs`, `.pfs.000`, …).
  static bool isPfsVolume(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.pfs') || RegExp(r'\.pfs\.\d+$').hasMatch(lower);
  }

  /// True for a KiriKiri archive the launcher accepts as a game entry.
  static bool isKrkrArchive(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.xp3') ||
        lower.endsWith('.zip') ||
        lower.endsWith('.7z') ||
        lower.endsWith('.tar');
  }

  /// Classify a library path without touching the filesystem where the
  /// extension already decides; falls back to a shallow directory listing.
  /// Returns [GameEngine.krkr2] when nothing Artemis-specific is found so
  /// legacy entries keep their behaviour.
  static GameEngine detect(String path) {
    if (isPfsPack(path)) return GameEngine.artemis;
    if (isKrkrArchive(path)) return GameEngine.krkr2;
    if (directoryHasPfs(path)) return GameEngine.artemis;
    return GameEngine.krkr2;
  }

  /// Whether [dirPath] directly contains a base `.pfs` pack.
  static bool directoryHasPfs(String dirPath) {
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return false;
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is File && isPfsPack(entity.path)) return true;
      }
    } on FileSystemException {
      // Unreadable directory: treat as not-Artemis.
    }
    return false;
  }

  /// Whether [dirPath] directly contains a `.xp3` archive.
  static bool directoryHasXp3(String dirPath) {
    return _xp3FilesIn(dirPath).isNotEmpty;
  }

  /// Path the KrKr runtime should actually open.
  ///
  /// Typical releases are a folder with `data.xp3` (and maybe `patch.xp3`)
  /// and no loose `startup.tjs` — that script lives inside the archive.
  /// The launcher keeps the folder as the library entry (so the card title
  /// stays the folder name) and this rewrites to `data.xp3` for
  /// `engine_open_game`. Sibling `patch.tjs` is then picked up via AppPath.
  static String resolveKrkrLaunchPath(String path) {
    if (isKrkrArchive(path) || isPfsPack(path)) return path;
    try {
      final dir = Directory(path);
      if (!dir.existsSync()) return path;
      for (final name in const [
        'startup.tjs',
        'Startup.tjs',
        'STARTUP.TJS',
      ]) {
        if (File('$path/$name').existsSync()) return path;
      }
      for (final name in const ['initialize.tjs', 'Initialize.tjs']) {
        if (File('$path/data/system/$name').existsSync()) return path;
      }
      final xp3s = _xp3FilesIn(path);
      if (xp3s.isEmpty) return path;
      for (final file in xp3s) {
        final base = file.split(RegExp(r'[/\\]')).last.toLowerCase();
        if (base == 'data.xp3') return file;
      }
      xp3s.sort();
      return xp3s.first;
    } on FileSystemException {
      return path;
    }
  }

  static List<String> _xp3FilesIn(String dirPath) {
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return const [];
      return [
        for (final entity in dir.listSync(followLinks: false))
          if (entity is File && entity.path.toLowerCase().endsWith('.xp3'))
            entity.path,
      ];
    } on FileSystemException {
      return const [];
    }
  }
}

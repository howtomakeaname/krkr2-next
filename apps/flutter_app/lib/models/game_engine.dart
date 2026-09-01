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
}

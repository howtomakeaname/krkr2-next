import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import '../l10n/app_localizations.dart';
import '../models/game_engine.dart';
import 'archive_volumes.dart';
import 'local_file_service.dart';

/// What a managed entry is, for icons, details and whether a tap opens a
/// viewer. Archives stay extractable; `.xp3` / `.pfs` are games, not zips.
/// Engine blobs (`.dat`, `.tlg`, `.asb`, …) are labeled but not opened.
enum ManagerFileKind {
  folder,
  game,
  archive,
  image,
  audio,
  video,
  text,
  gameData,
  file;

  bool get canOpen =>
      this == image || this == audio || this == video || this == text;

  IconData get icon => switch (this) {
    ManagerFileKind.folder => CupertinoIcons.folder,
    ManagerFileKind.game => CupertinoIcons.game_controller,
    ManagerFileKind.archive => CupertinoIcons.archivebox,
    ManagerFileKind.image => CupertinoIcons.photo,
    ManagerFileKind.audio => CupertinoIcons.music_note_2,
    ManagerFileKind.video => CupertinoIcons.play_rectangle,
    ManagerFileKind.text => CupertinoIcons.doc_text,
    ManagerFileKind.gameData => CupertinoIcons.square_stack_3d_up,
    ManagerFileKind.file => CupertinoIcons.doc,
  };

  String label(AppLocalizations l10n) => switch (this) {
    ManagerFileKind.folder => l10n.managerDetailFolder,
    ManagerFileKind.game => l10n.managerDetailGame,
    ManagerFileKind.archive => l10n.managerDetailArchive,
    ManagerFileKind.image => l10n.managerDetailImage,
    ManagerFileKind.audio => l10n.managerDetailAudio,
    ManagerFileKind.video => l10n.managerDetailVideo,
    ManagerFileKind.text => l10n.managerDetailText,
    ManagerFileKind.gameData => l10n.managerDetailGameData,
    ManagerFileKind.file => l10n.managerDetailFile,
  };

  static ManagerFileKind of(LocalFileEntry entry) {
    if (entry.isDirectory) return ManagerFileKind.folder;
    return ofName(entry.name);
  }

  /// Last `.ext` in [name], lowercased. Empty when the name has no suffix.
  static String extensionOf(String name) => _ext(name.toLowerCase());

  /// True when the last suffix changes, ignoring case (`a.TXT` → `a.txt`).
  static bool extensionChanged(String from, String to) =>
      extensionOf(from) != extensionOf(to);

  static ManagerFileKind ofName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.xp3') || GameEngine.isPfsVolume(name)) {
      return ManagerFileKind.game;
    }
    if (ArchiveVolumes.isVolume(name) || _archives.contains(_ext(lower))) {
      return ManagerFileKind.archive;
    }
    if (_images.contains(_ext(lower))) return ManagerFileKind.image;
    if (_audio.contains(_ext(lower))) return ManagerFileKind.audio;
    if (_videos.contains(_ext(lower))) return ManagerFileKind.video;
    if (_gameData.contains(_ext(lower))) return ManagerFileKind.gameData;
    if (_texts.contains(_ext(lower))) return ManagerFileKind.text;
    return ManagerFileKind.file;
  }

  static String _ext(String lowerName) {
    final dot = lowerName.lastIndexOf('.');
    if (dot <= 0 || dot == lowerName.length - 1) return '';
    return lowerName.substring(dot + 1);
  }

  static const _images = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
    'tif',
    'tiff',
    'svg',
  };

  static const _audio = {
    'mp3',
    'm4a',
    'aac',
    'wav',
    'flac',
    'ogg',
    'oga',
    'opus',
    'wma',
    'aiff',
    'caf',
  };

  static const _videos = {
    'mp4',
    'mov',
    'm4v',
    'webm',
    'mkv',
    'avi',
    '3gp',
    'mpeg',
    'mpg',
    'ts',
    'flv',
    'wmv',
  };

  static const _texts = {
    'txt',
    'text',
    'md',
    'markdown',
    'rst',
    'csv',
    'tsv',
    'json',
    'xml',
    'html',
    'htm',
    'css',
    'js',
    'mjs',
    'ts',
    'jsx',
    'tsx',
    'yaml',
    'yml',
    'toml',
    'ini',
    'inf',
    'cfg',
    'conf',
    'properties',
    'log',
    'nfo',
    'cue',
    'lrc',
    'srt',
    'ass',
    'ssa',
    'vtt',
    'm3u',
    'm3u8',
    'dart',
    'py',
    'c',
    'h',
    'cpp',
    'hpp',
    'java',
    'kt',
    'rs',
    'go',
    'sh',
    'bat',
    'ps1',
    'ks',
    'tjs',
    'iet',
    'ast',
  };

  /// Kirikiri / Artemis blobs the manager cannot preview or extract.
  static const _gameData = {
    'dat',
    'ksd',
    'tlg',
    'tlg5',
    'tlg6',
    'asd',
    'asb',
    'tfm',
    'tft',
    'kdt',
    'nwa',
    'nwk',
    'ovk',
    'waf',
    'scn',
  };

  static const _archives = {
    'zip',
    '7z',
    'rar',
    'tar',
    'gz',
    'bz2',
    'xz',
    'zst',
  };
}

/// First [previewLimit] bytes of a text file. Larger files are truncated so
/// a multi-megabyte log cannot freeze the viewer.
const managerTextPreviewLimit = 2 * 1024 * 1024;

class ManagerTextPreview {
  const ManagerTextPreview({required this.text, required this.truncated});
  final String text;
  final bool truncated;
}

/// UTF-8, UTF-16 (BOM) or a best-effort UTF-8 decode so CJK in a `.txt`
/// still shows instead of throwing.
ManagerTextPreview decodeManagedText(Uint8List bytes, {int? limit}) {
  final cap = limit ?? managerTextPreviewLimit;
  final truncated = bytes.length > cap;
  final slice = truncated ? Uint8List.sublistView(bytes, 0, cap) : bytes;
  return ManagerTextPreview(text: _decodeBytes(slice), truncated: truncated);
}

String _decodeBytes(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return _utf16(bytes.sublist(2), bigEndian: false);
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return _utf16(bytes.sublist(2), bigEndian: true);
  }
  return utf8.decode(bytes, allowMalformed: true);
}

String _utf16(Uint8List bytes, {required bool bigEndian}) {
  final units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    units.add(
      bigEndian ? (bytes[i] << 8) | bytes[i + 1] : bytes[i] | (bytes[i + 1] << 8),
    );
  }
  return String.fromCharCodes(units);
}

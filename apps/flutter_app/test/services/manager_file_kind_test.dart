import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/services/manager_file_kind.dart';

void main() {
  test('classifies game packs, media, text and archives by name', () {
    expect(ManagerFileKind.ofName('data.xp3'), ManagerFileKind.game);
    expect(ManagerFileKind.ofName('root.pfs'), ManagerFileKind.game);
    expect(ManagerFileKind.ofName('root.pfs.000'), ManagerFileKind.game);
    expect(ManagerFileKind.ofName('cover.png'), ManagerFileKind.image);
    expect(ManagerFileKind.ofName('photo.HEIC'), ManagerFileKind.image);
    expect(ManagerFileKind.ofName('bgm.mp3'), ManagerFileKind.audio);
    expect(ManagerFileKind.ofName('op.mp4'), ManagerFileKind.video);
    expect(ManagerFileKind.ofName('pack.7z'), ManagerFileKind.archive);
    expect(ManagerFileKind.ofName('pack.7z.001'), ManagerFileKind.archive);
    expect(ManagerFileKind.ofName('readme.txt'), ManagerFileKind.text);
    expect(ManagerFileKind.ofName('first.ks'), ManagerFileKind.text);
    expect(ManagerFileKind.ofName('Config.tjs'), ManagerFileKind.text);
    expect(ManagerFileKind.ofName('save0001.dat'), ManagerFileKind.gameData);
    expect(ManagerFileKind.ofName('save.ksd'), ManagerFileKind.gameData);
    expect(ManagerFileKind.ofName('system.dat'), ManagerFileKind.gameData);
    expect(ManagerFileKind.ofName('bg.tlg'), ManagerFileKind.gameData);
    expect(ManagerFileKind.ofName('first.asb'), ManagerFileKind.gameData);
    expect(ManagerFileKind.ofName('notes.bin'), ManagerFileKind.file);
  });

  test('pictures, AV and text can be opened', () {
    expect(ManagerFileKind.image.canOpen, isTrue);
    expect(ManagerFileKind.audio.canOpen, isTrue);
    expect(ManagerFileKind.video.canOpen, isTrue);
    expect(ManagerFileKind.text.canOpen, isTrue);
    expect(ManagerFileKind.game.canOpen, isFalse);
    expect(ManagerFileKind.archive.canOpen, isFalse);
    expect(ManagerFileKind.gameData.canOpen, isFalse);
    expect(ManagerFileKind.file.canOpen, isFalse);
  });

  test('detects when a rename changes the last extension', () {
    expect(ManagerFileKind.extensionChanged('notes.bin', 'other.bin'), isFalse);
    expect(ManagerFileKind.extensionChanged('notes.bin', 'notes.BIN'), isFalse);
    expect(ManagerFileKind.extensionChanged('notes.bin', 'notes.dat'), isTrue);
    expect(ManagerFileKind.extensionChanged('notes.bin', 'notes'), isTrue);
    expect(ManagerFileKind.extensionChanged('pack.7z.001', 'pack.7z.002'), isTrue);
  });

  test('decodes UTF-8, BOM variants and truncates large files', () {
    expect(
      decodeManagedText(Uint8List.fromList(utf8.encode('日本語 中文'))).text,
      '日本語 中文',
    );

    final utf8Bom = decodeManagedText(
      Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('ok')]),
    );
    expect(utf8Bom.text, 'ok');
    expect(utf8Bom.truncated, isFalse);

    final utf16le = decodeManagedText(
      Uint8List.fromList([0xFF, 0xFE, 0x4F, 0x00, 0x4B, 0x00]),
    );
    expect(utf16le.text, 'OK');

    final utf16be = decodeManagedText(
      Uint8List.fromList([0xFE, 0xFF, 0x00, 0x4F, 0x00, 0x4B]),
    );
    expect(utf16be.text, 'OK');

    final big = decodeManagedText(
      Uint8List.fromList(List<int>.filled(8, 0x61)),
      limit: 4,
    );
    expect(big.text, 'aaaa');
    expect(big.truncated, isTrue);
  });
}

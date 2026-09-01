// Host-side XP3 inspection helper (pure Dart, no Flutter imports).
//
// Usage:
//   dart run tool/xp3_host.dart list <data.xp3> [pattern]
//   dart run tool/xp3_host.dart extract <data.xp3> <destDir> [pattern]
//
// "pattern" is a case-insensitive substring or extension filter like ".tjs".
import 'dart:io';

import '../lib/utils/xp3_utils.dart';

void main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/xp3_host.dart <list|extract> <xp3> [destDir] [pattern]');
    exit(2);
  }
  final mode = args[0];
  final xp3 = args[1];

  if (mode == 'list') {
    final pattern = args.length > 2 ? args[2].toLowerCase() : null;
    final infos = await xp3List(xp3);
    var total = 0;
    var shown = 0;
    final byExt = <String, (int count, int size)>{};
    for (final info in infos) {
      total += info.size;
      final dot = info.name.lastIndexOf('.');
      final ext = dot >= 0 ? info.name.substring(dot).toLowerCase() : '(none)';
      final prev = byExt[ext] ?? (0, 0);
      byExt[ext] = (prev.$1 + 1, prev.$2 + info.size);
      if (pattern == null || info.name.toLowerCase().contains(pattern)) {
        shown += info.size;
        stdout.writeln('${info.size.toString().padLeft(12)}  ${info.name}');
      }
    }
    stdout.writeln('---');
    final sorted = byExt.entries.toList()
      ..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    for (final e in sorted.take(25)) {
      stdout.writeln(
          '${e.value.$2.toString().padLeft(12)}  ${e.value.$1.toString().padLeft(5)}x  ${e.key}');
    }
    stdout.writeln(
        'total=${total / 1024 / 1024}MB in ${infos.length} files; shown=${shown / 1024 / 1024}MB');
  } else if (mode == 'extract') {
    final dest = args[2];
    await Directory(dest).create(recursive: true);
    await xp3Extract(xp3, dest, onProgress: (p, f) {
      if (p.isNaN || f.isEmpty) return;
      stdout.writeln('${(p * 100).toStringAsFixed(1)}%  $f');
    });
    stdout.writeln('done -> $dest');
  } else {
    stderr.writeln('unknown mode: $mode');
    exit(2);
  }
}

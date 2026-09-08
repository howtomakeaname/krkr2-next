import 'package:path/path.dart' as p;

/// Split archives are a group. Renaming the first volume alone would leave
/// the remaining parts unreachable.
class ArchiveVolumes {
  ArchiveVolumes._();

  static final _numeric = RegExp(r'^(.+)\.(\d{3})$', caseSensitive: false);
  static final _rarPart = RegExp(
    r'^(.+)\.part(\d+)\.rar$',
    caseSensitive: false,
  );

  static bool isVolume(String name) =>
      _numeric.hasMatch(name) || _rarPart.hasMatch(name);

  static String? groupKey(String name) {
    final rar = _rarPart.firstMatch(name);
    if (rar != null) return '${rar.group(1)!.toLowerCase()}|rar-part';
    final numeric = _numeric.firstMatch(name);
    if (numeric != null) return '${numeric.group(1)!.toLowerCase()}|num';
    return null;
  }

  static List<String> members(String name, Iterable<String> names) {
    final key = groupKey(name);
    if (key == null) return [name];
    final grouped = names.where((candidate) => groupKey(candidate) == key);
    return grouped.isEmpty ? [name] : grouped.toList();
  }

  static String renamedMember(String member, String fromName, String toName) {
    final fromNumeric = _numeric.firstMatch(fromName);
    final toNumeric = _numeric.firstMatch(toName);
    final memberNumeric = _numeric.firstMatch(member);
    if (fromNumeric != null && toNumeric != null && memberNumeric != null) {
      return '${toNumeric.group(1)}.${memberNumeric.group(2)}';
    }
    final fromRar = _rarPart.firstMatch(fromName);
    final toRar = _rarPart.firstMatch(toName);
    final memberRar = _rarPart.firstMatch(member);
    if (fromRar != null && toRar != null && memberRar != null) {
      return '${toRar.group(1)}.part${memberRar.group(2)}.rar';
    }
    return member == fromName ? toName : member;
  }

  /// Destination folder next to the archive. Volumes share one folder named
  /// after the group prefix (`pack.7z.001` → `pack.7z`).
  static String extractFolderName(String name) {
    final rar = _rarPart.firstMatch(name);
    if (rar != null) return rar.group(1)!;
    final numeric = _numeric.firstMatch(name);
    if (numeric != null) return numeric.group(1)!;
    var folder = name;
    for (final suffix in ['.tar.gz', '.tar.bz2', '.tar.xz', '.tar.zst']) {
      if (folder.toLowerCase().endsWith(suffix)) {
        return folder.substring(0, folder.length - suffix.length);
      }
    }
    return p.basenameWithoutExtension(folder);
  }
}

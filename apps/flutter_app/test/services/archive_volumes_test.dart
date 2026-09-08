import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/archive_volumes.dart';

void main() {
  test('keeps numeric volumes in one group', () {
    const names = ['物語.7z.001', '物語.7z.002', '物語.7z.003', 'other.zip'];
    expect(ArchiveVolumes.members('物語.7z.001', names), [
      '物語.7z.001',
      '物語.7z.002',
      '物語.7z.003',
    ]);
    expect(
      ArchiveVolumes.renamedMember('物語.7z.002', '物語.7z.001', '改名.7z.001'),
      '改名.7z.002',
    );
  });

  test('keeps rar parts in one group', () {
    const names = ['pack.part1.rar', 'pack.part2.rar', 'pack.rar'];
    expect(ArchiveVolumes.members('pack.part2.rar', names), [
      'pack.part1.rar',
      'pack.part2.rar',
    ]);
  });
}

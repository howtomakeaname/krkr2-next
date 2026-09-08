import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/engine_runtime_guard.dart';
import 'package:flutter_app/services/file_operation_error.dart';

void main() {
  test('active game page blocks overlapping file changes', () async {
    final guard = EngineRuntimeGuard(
      isPageActive: () => true,
      pagePath: () => '/dl/app/games/running',
    );
    expect(guard.overlaps('/dl/app/games/running/data.xp3'), isTrue);
    await expectLater(
      guard.prepareMutation('/dl/app/games/running'),
      throwsA(
        isA<FileOperationException>().having(
          (error) => error.code,
          'code',
          FileErrorCode.gameRunning,
        ),
      ),
    );
  });

  test('parked runtime is released before a conflicting rename', () async {
    var parked = '/dl/app/games/parked';
    var released = false;
    final guard = EngineRuntimeGuard(
      isPageActive: () => false,
      parkedPath: () => parked,
      releaseParked: () async {
        released = true;
        parked = '';
      },
    );
    await guard.prepareMutation('/dl/app/games/parked');
    expect(released, isTrue);
  });

  test('a sibling folder is not treated as the same game', () {
    final guard = EngineRuntimeGuard(
      isPageActive: () => true,
      pagePath: () => '/dl/app/games/game',
    );
    expect(guard.overlaps('/dl/app/games/game-2'), isFalse);
  });
}

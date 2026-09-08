import 'dart:io';

import 'package:flutter/services.dart';

/// Stable wire codes shared with platform adapters and the native archive API.
/// Do not send translated strings across that boundary. Unknown/new codes must
/// remain safe to display in older clients through [FileErrorCode.failed].
enum FileErrorCode {
  cancelled('cancelled'),
  busy('busy'),
  invalidName('invalid_name'),
  outsideRoot('outside_root'),
  protectedDirectory('protected_directory'),
  unsupportedLink('unsupported_link'),
  notFound('not_found'),
  conflict('conflict'),
  recursiveTarget('recursive_target'),
  trashCorrupt('trash_corrupt'),
  permissionDenied('permission_denied'),
  noSpace('no_space'),
  readOnly('read_only'),
  passwordRequired('password_required'),
  wrongPassword('wrong_password'),
  missingVolume('missing_volume'),
  unsupportedFormat('unsupported_format'),
  unsupportedMethod('unsupported_method'),
  corruptArchive('corrupt_archive'),
  invalidEncoding('invalid_encoding'),
  unsafeArchivePath('unsafe_archive_path'),
  archiveLimit('archive_limit'),
  gameRunning('game_running'),
  unsupportedPlatform('unsupported_platform'),
  failed('failed');

  const FileErrorCode(this.wireCode);
  final String wireCode;

  static FileErrorCode fromWire(String? code) => values.firstWhere(
    (value) => value.wireCode == code,
    orElse: () => failed,
  );
}

class FileOperationException implements Exception {
  const FileOperationException(this.code, {this.osCode});
  final FileErrorCode code;
  final int? osCode;

  static FileOperationException from(Object error) {
    if (error is FileOperationException) return error;
    if (error is PlatformException) {
      return FileOperationException(FileErrorCode.fromWire(error.code));
    }
    if (error is FileSystemException) {
      final errno = error.osError?.errorCode;
      // POSIX errno is available on HarmonyOS, Android and Apple platforms.
      // Keep raw exception messages out of UI (they may contain private paths).
      return FileOperationException(switch (errno) {
        1 || 13 => FileErrorCode.permissionDenied,
        2 => FileErrorCode.notFound,
        17 => FileErrorCode.conflict,
        28 => FileErrorCode.noSpace,
        30 => FileErrorCode.readOnly,
        36 => FileErrorCode.invalidName,
        _ => FileErrorCode.failed,
      }, osCode: errno);
    }
    return const FileOperationException(FileErrorCode.failed);
  }

  @override
  String toString() =>
      'FileOperationException(${code.wireCode}, errno: $osCode)';
}

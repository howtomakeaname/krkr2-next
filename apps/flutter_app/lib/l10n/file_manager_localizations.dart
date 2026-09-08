import '../services/file_operation_error.dart';
import 'app_localizations.dart';

/// The sole error-to-copy boundary: file services never choose UI language.
extension FileManagerLocalizations on AppLocalizations {
  String fileOperationError(FileErrorCode code) => switch (code) {
    FileErrorCode.cancelled => managerErrorCancelled,
    FileErrorCode.busy => managerErrorBusy,
    FileErrorCode.invalidName => managerErrorInvalidName,
    FileErrorCode.outsideRoot => managerErrorOutsideRoot,
    FileErrorCode.protectedDirectory => managerErrorProtectedDirectory,
    FileErrorCode.unsupportedLink => managerErrorUnsupportedLink,
    FileErrorCode.notFound => managerErrorNotFound,
    FileErrorCode.conflict => managerErrorConflict,
    FileErrorCode.recursiveTarget => managerErrorRecursiveTarget,
    FileErrorCode.trashCorrupt => managerErrorTrashCorrupt,
    FileErrorCode.permissionDenied => managerErrorPermissionDenied,
    FileErrorCode.noSpace => managerErrorNoSpace,
    FileErrorCode.readOnly => managerErrorReadOnly,
    FileErrorCode.passwordRequired => managerErrorPasswordRequired,
    FileErrorCode.wrongPassword => managerErrorWrongPassword,
    FileErrorCode.missingVolume => managerErrorMissingVolume,
    FileErrorCode.unsupportedFormat => managerErrorUnsupportedFormat,
    FileErrorCode.unsupportedMethod => managerErrorUnsupportedMethod,
    FileErrorCode.corruptArchive => managerErrorCorruptArchive,
    FileErrorCode.invalidEncoding => managerErrorInvalidEncoding,
    FileErrorCode.unsafeArchivePath => managerErrorUnsafeArchivePath,
    FileErrorCode.archiveLimit => managerErrorArchiveLimit,
    FileErrorCode.gameRunning => managerErrorGameRunning,
    FileErrorCode.unsupportedPlatform => managerErrorUnsupportedPlatform,
    FileErrorCode.failed => managerErrorFailed,
  };
}

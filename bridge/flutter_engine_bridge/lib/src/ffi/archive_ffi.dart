import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// C ABI from bridge/file_archive/archive_api.h. Loaded independently of
/// engineCreate so extraction never starts a game runtime.
final class ArchiveStatusNative extends Struct {
  @Int32()
  external int state;

  @Uint32()
  external int files;

  @Uint64()
  external int completed;

  @Uint64()
  external int total;

  @Array(1024)
  external Array<Uint8> current;

  @Array(1024)
  external Array<Uint8> error;
}

typedef _StartNative =
    Pointer<Void> Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Uint32,
    );
typedef _StartDart =
    Pointer<Void> Function(
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      Pointer<Utf8>,
      int,
    );
typedef _PollNative =
    Void Function(Pointer<Void>, Pointer<ArchiveStatusNative>);
typedef _PollDart = void Function(Pointer<Void>, Pointer<ArchiveStatusNative>);
typedef _JobNative = Void Function(Pointer<Void>);
typedef _JobDart = void Function(Pointer<Void>);

class ArchiveJobStatus {
  const ArchiveJobStatus({
    required this.state,
    required this.files,
    required this.completed,
    required this.total,
    required this.currentName,
    required this.errorCode,
  });

  /// 1 working, 2 success, 3 failed, 4 cancelled
  final int state;
  final int files;
  final int completed;
  final int total;
  final String currentName;
  final String errorCode;

  bool get isWorking => state == 1;
  bool get isSuccess => state == 2;
  bool get isFailed => state == 3;
  bool get isCancelled => state == 4;
}

class ArchiveFfi {
  ArchiveFfi._(this._start, this._poll, this._cancel, this._destroy);

  final _StartDart _start;
  final _PollDart _poll;
  final _JobDart _cancel;
  final _JobDart _destroy;
  static String lastLoadError = '';

  static ArchiveFfi? tryCreate({String? libraryPath}) {
    lastLoadError = '';
    final library = _open(libraryPath);
    if (library == null) return null;
    try {
      return ArchiveFfi._(
        library.lookupFunction<_StartNative, _StartDart>('krkr_archive_start'),
        library.lookupFunction<_PollNative, _PollDart>('krkr_archive_poll'),
        library.lookupFunction<_JobNative, _JobDart>('krkr_archive_cancel'),
        library.lookupFunction<_JobNative, _JobDart>('krkr_archive_destroy'),
      );
    } catch (error) {
      lastLoadError = 'Failed to bind file_archive symbols: $error';
      return null;
    }
  }

  Pointer<Void> start({
    required String root,
    required String source,
    required String destination,
    String? password,
    int legacyCodepage = 65001,
  }) {
    final rootPtr = root.toNativeUtf8();
    final sourcePtr = source.toNativeUtf8();
    final destinationPtr = destination.toNativeUtf8();
    final passwordPtr = (password ?? '').toNativeUtf8();
    // toNativeUtf8 length is in bytes, not UTF-16 units: a CJK or emoji
    // password is longer than password.length.
    final passwordBytes = passwordPtr.length;
    try {
      return _start(
        rootPtr,
        sourcePtr,
        destinationPtr,
        passwordPtr,
        legacyCodepage,
      );
    } finally {
      malloc.free(rootPtr);
      malloc.free(sourcePtr);
      malloc.free(destinationPtr);
      // Password is copied by native code; wipe the Dart-side buffer we own.
      final bytes = passwordPtr.cast<Uint8>();
      for (var i = 0; i <= passwordBytes; i++) {
        bytes[i] = 0;
      }
      malloc.free(passwordPtr);
    }
  }

  ArchiveJobStatus poll(Pointer<Void> job) {
    final status = calloc<ArchiveStatusNative>();
    try {
      _poll(job, status);
      return ArchiveJobStatus(
        state: status.ref.state,
        files: status.ref.files,
        completed: status.ref.completed,
        total: status.ref.total,
        currentName: _fixedUtf8(status.ref.current),
        errorCode: _fixedUtf8(status.ref.error),
      );
    } finally {
      calloc.free(status);
    }
  }

  void cancel(Pointer<Void> job) => _cancel(job);

  /// Joins the worker. Call only after a terminal poll, from a yield, so the
  /// UI isolate is not blocked for the whole extraction.
  void destroy(Pointer<Void> job) => _destroy(job);

  static DynamicLibrary? _open(String? libraryPath) {
    final override = libraryPath?.trim() ?? '';
    final names = override.isNotEmpty ? [override] : _candidateNames();
    final errors = <String>[];
    for (final name in names) {
      try {
        return DynamicLibrary.open(name);
      } catch (error) {
        errors.add('open("$name") failed: $error');
      }
    }
    lastLoadError = errors.join('\n');
    return null;
  }

  static List<String> _candidateNames() {
    if (Platform.isMacOS) return const ['libfile_archive.dylib'];
    if (Platform.isWindows) return const ['file_archive.dll'];
    return const ['libfile_archive.so'];
  }

  /// Native truncates `current` at 1023 bytes, which can split a multi-byte
  /// sequence; decode leniently so a long CJK name still displays.
  static String _fixedUtf8(Array<Uint8> bytes) {
    final out = <int>[];
    for (var i = 0; i < 1024; i++) {
      final value = bytes[i];
      if (value == 0) break;
      out.add(value);
    }
    return utf8.decode(out, allowMalformed: true);
  }
}

import 'dart:async';

import 'package:flutter_engine_bridge/flutter_engine_bridge.dart';

import 'local_file_service.dart';

/// Polls the native archive job without blocking the UI isolate on destroy.
class ArchiveExtractor {
  ArchiveExtractor({ArchiveFfi? ffi}) : _ffi = ffi ?? ArchiveFfi.tryCreate();

  final ArchiveFfi? _ffi;

  bool get isAvailable => _ffi != null;

  Future<void> unpack({
    required String root,
    required String source,
    required String destination,
    String? password,
    int legacyCodepage = 65001,
    FileTask? task,
  }) async {
    final ffi = _ffi;
    if (ffi == null) {
      throw const FileOperationException(FileErrorCode.unsupportedPlatform);
    }
    final job = ffi.start(
      root: root,
      source: source,
      destination: destination,
      password: password,
      legacyCodepage: legacyCodepage,
    );
    if (job.address == 0) {
      throw const FileOperationException(FileErrorCode.failed);
    }
    try {
      while (true) {
        if (task?.cancelled == true) ffi.cancel(job);
        final status = ffi.poll(job);
        if (task != null) {
          task.completed = status.completed.toInt();
          task.total = status.total == 0 ? 1 : status.total.toInt();
          task.currentName = status.currentName;
          task.report();
        }
        if (!status.isWorking) {
          if (status.isCancelled || task?.cancelled == true) {
            throw const FileOperationException(FileErrorCode.cancelled);
          }
          if (status.isFailed) {
            throw FileOperationException(
              FileErrorCode.fromWire(
                status.errorCode.isEmpty ? 'failed' : status.errorCode,
              ),
            );
          }
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 32));
      }
    } finally {
      // Terminal state has already joined the useful work; destroy only
      // waits for the worker to exit its last bookkeeping.
      await Future<void>(() => ffi.destroy(job));
    }
  }
}

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/l10n/app_localizations_en.dart';
import 'package:flutter_app/l10n/app_localizations_ja.dart';
import 'package:flutter_app/l10n/app_localizations_zh.dart';
import 'package:flutter_app/l10n/file_manager_localizations.dart';
import 'package:flutter_app/services/file_operation_error.dart';

void main() {
  test('wire codes are unique and unknown versions have a safe fallback', () {
    expect(
      FileErrorCode.values.map((c) => c.wireCode).toSet().length,
      FileErrorCode.values.length,
    );
    for (final code in FileErrorCode.values) {
      expect(FileErrorCode.fromWire(code.wireCode), code);
    }
    expect(FileErrorCode.fromWire('new_native_error'), FileErrorCode.failed);
  });

  test('every error has Chinese, English and Japanese copy', () {
    final locales = [
      AppLocalizationsZh(),
      AppLocalizationsEn(),
      AppLocalizationsJa(),
    ];
    for (final code in FileErrorCode.values) {
      final messages = locales
          .map((locale) => locale.fileOperationError(code))
          .toList();
      expect(
        messages.every(
          (message) => message.isNotEmpty && message != code.wireCode,
        ),
        isTrue,
      );
      expect(messages.toSet().length, 3);
    }
  });

  test('platform and filesystem exceptions never become raw UI copy', () {
    final error = FileOperationException.from(
      PlatformException(
        code: 'wrong_password',
        message: 'private path and native details',
      ),
    );
    expect(error.code, FileErrorCode.wrongPassword);
    expect(
      AppLocalizationsZh().fileOperationError(error.code),
      isNot(contains('private')),
    );
    expect(
      FileOperationException.from(
        const FileSystemException(
          'write failed',
          '/private/path',
          OSError('full', 28),
        ),
      ).code,
      FileErrorCode.noSpace,
    );
    expect(
      FileOperationException.from(StateError('private diagnostic')).code,
      FileErrorCode.failed,
    );
  });
}

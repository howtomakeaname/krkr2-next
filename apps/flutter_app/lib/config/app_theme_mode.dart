import 'package:flutter/material.dart';

/// Persisted application theme choices and their Flutter representation.
abstract final class AppThemeMode {
  static const String system = 'system';
  static const String light = 'light';
  static const String dark = 'dark';
  static const String defaultCode = dark;

  static String normalize(String? code) {
    return switch (code) {
      system => system,
      light => light,
      dark => dark,
      _ => defaultCode,
    };
  }

  static ThemeMode fromCode(String? code) {
    return switch (normalize(code)) {
      system => ThemeMode.system,
      light => ThemeMode.light,
      _ => ThemeMode.dark,
    };
  }
}

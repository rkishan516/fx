import 'dart:io';

/// Log levels for the fx logger.
enum LogLevel { verbose, info, warning, error, silent }

/// Simple logger with ANSI color support.
class Logger {
  static LogLevel _level = LogLevel.info;
  static bool _useColor = true;

  /// Set the global log level.
  static void setLevel(LogLevel level) => _level = level;

  /// Enable or disable ANSI colors.
  static void setColor(bool useColor) => _useColor = useColor;

  static void verbose(String message) {
    if (_level.index <= LogLevel.verbose.index) {
      _write(message, _gray);
    }
  }

  static void info(String message) {
    if (_level.index <= LogLevel.info.index) {
      _write(message, null);
    }
  }

  static void success(String message) {
    if (_level.index <= LogLevel.info.index) {
      _write(message, _green);
    }
  }

  static void warning(String message) {
    if (_level.index <= LogLevel.warning.index) {
      _write(message, _yellow);
    }
  }

  static void error(String message) {
    if (_level.index <= LogLevel.error.index) {
      stderr.writeln(_color('ERROR: $message', _red));
    }
  }

  static void progress(String message) {
    if (_level.index <= LogLevel.info.index) {
      _write('  $message', _cyan);
    }
  }

  static void _write(String message, String? colorCode) {
    stdout.writeln(_color(message, colorCode));
  }

  static String _color(String text, String? code) {
    if (!_useColor || code == null) return text;
    return '$code$text$_reset';
  }

  static const String _reset = '\x1B[0m';
  static const String _red = '\x1B[31m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _cyan = '\x1B[36m';
  static const String _gray = '\x1B[90m';
}

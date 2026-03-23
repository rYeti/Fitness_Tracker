import 'package:logger/logger.dart';

class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  /// Debug log - for detailed diagnostic information
  static void d(String message) => _logger.d(message);

  /// Info log - for general informational messages
  static void i(String message) => _logger.i(message);

  /// Warning log - for potentially harmful situations
  static void w(String message) => _logger.w(message);

  /// Error log - for error events
  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Verbose/trace log - for very detailed information
  static void t(String message) => _logger.t(message);
}

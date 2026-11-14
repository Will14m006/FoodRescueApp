import 'dart:developer' as developer;

/// P10: log runtime terpusat supaya masalah saat aplikasi berjalan bisa
/// dilacak. Muncul di `flutter run` / DevTools console dan di `adb logcat`.
///
/// Tidak memakai package tambahan — `dart:developer` sudah bawaan Dart.
/// Di build release, `log` tetap murah (tidak menulis file, tidak blocking).
abstract class AppLog {
  static const _name = 'FoodRescue';

  static void info(String message) {
    developer.log(message, name: _name, level: 800);
  }

  static void warn(String message, [Object? error]) {
    developer.log(
      message,
      name: _name,
      level: 900,
      error: error,
    );
  }

  static void error(String message, [Object? error, StackTrace? stack]) {
    developer.log(
      message,
      name: _name,
      level: 1000,
      error: error,
      stackTrace: stack,
    );
  }
}

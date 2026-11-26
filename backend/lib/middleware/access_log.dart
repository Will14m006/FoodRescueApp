import 'package:shelf/shelf.dart';

/// Log akses satu baris per request.
///
/// Diganti dari `logRequests()` bawaan shelf karena dua alasan:
///   1. Bawaan shelf mencetak **stack trace panjang** setiap kali handler
///      melempar exception — termasuk `ApiException` yang statusnya 4xx dan
///      sepenuhnya normal (password salah, role salah). Log jadi sampah.
///   2. Bawaan shelf memakai `print` langsung, sehingga tidak bisa diarahkan
///      ke logger aplikasi maupun diuji.
///
/// Yang dicatat hanya method, path, status, dan durasi. **Tidak** ada query
/// string, header, body, atau token.
Middleware accessLog(void Function(String message) log) {
  return (Handler inner) {
    return (Request request) async {
      final watch = Stopwatch()..start();
      try {
        final response = await inner(request);
        watch.stop();
        log(
          '${request.method.padRight(6)} ${response.statusCode} '
          '/${request.url.path} ${watch.elapsedMilliseconds}ms',
        );
        return response;
      } catch (_) {
        // Exception akan ditangani errorHandler (di luar) menjadi 500.
        // Dicatat di sini supaya setiap request tetap punya tepat satu baris.
        watch.stop();
        log(
          '${request.method.padRight(6)} 500 '
          '/${request.url.path} ${watch.elapsedMilliseconds}ms',
        );
        rethrow;
      }
    };
  };
}

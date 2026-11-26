import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'auth/jwt_service.dart';
import 'auth/login_throttle.dart';
import 'auth/password_hasher.dart';
import 'db/database.dart';
import 'middleware/access_log.dart';
import 'middleware/api_response.dart';
import 'middleware/cors.dart';
import 'middleware/security_headers.dart';
import 'routes/router.dart';

/// Merakit handler lengkap: pipeline middleware + router.
///
/// Urutan tidak boleh ditukar. Middleware yang ditambahkan lebih dulu berada
/// **lebih luar**:
///   1. `SecurityHeaders` — harus paling luar supaya respons 500 buatan
///      `errorHandler` pun tetap mendapat header keamanan.
///   2. `accessLog` — di luar `errorHandler` supaya yang dicatat adalah status
///      **akhir** (401/403/500), bukan exception mentah.
///   3. `errorHandler` — mengubah exception menjadi JSON. `ApiException`
///      (401/403/422/…) tidak dianggap kesalahan server.
///   4. router.
///
/// `logRequests()` bawaan shelf sengaja **tidak** dipakai: ia mencetak stack
/// trace untuk setiap exception, termasuk 401 yang normal.
Handler buildHandler({
  required void Function(String message) log,
  required AppDatabase db,
  required JwtService jwt,
  required PasswordHasher hasher,
  required LoginThrottle throttle,
  List<String> corsOrigins = const [],
}) {
  return const Pipeline()
      // SecurityHeaders paling luar: preflight 204 buatan CORS pun tetap
      // mendapat header keamanan.
      .addMiddleware(SecurityHeaders.apply)
      // CORS di luar accessLog: preflight tidak perlu masuk log.
      .addMiddleware(Cors(corsOrigins).apply)
      .addMiddleware(accessLog(log))
      .addMiddleware(
        errorHandler((error, stack) {
          log('UNHANDLED: $error\n$stack');
        }),
      )
      .addHandler(
        buildRouter(db: db, jwt: jwt, hasher: hasher, throttle: throttle).call,
      );
}

/// Menjalankan server. Dipanggil dari `bin/server.dart` dan dari test.
///
/// `poweredByHeader: null` mematikan header `x-powered-by` — cara resmi shelf,
/// karena `dart:io` akan menambahkannya kembali bila hanya dihapus di handler.
Future<HttpServer> serve({
  required String host,
  required int port,
  required Handler handler,
}) {
  return shelf_io.serve(handler, host, port, poweredByHeader: null);
}

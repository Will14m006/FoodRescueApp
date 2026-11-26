import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'middleware/api_response.dart';
import 'middleware/security_headers.dart';
import 'routes/router.dart';

/// Merakit handler lengkap: pipeline middleware + router.
///
/// Urutan tidak boleh ditukar:
///   1. `errorHandler` — menangkap exception lebih dulu supaya respons 500
///      tetap JSON dan tetap punya header keamanan.
///   2. `SecurityHeaders` — header keamanan di semua respons.
///   3. `logRequests` — log akses. Shelf mencatat method + path saja, tidak
///      mencatat header Authorization.
///   4. router.
Handler buildHandler(void Function(String message) log) {
  return const Pipeline()
      .addMiddleware(
        errorHandler((error, stack) {
          log('UNHANDLED: $error\n$stack');
        }),
      )
      .addMiddleware(SecurityHeaders.apply)
      .addMiddleware(logRequests())
      .addHandler(buildRouter().call);
}

/// Menjalankan server. Dipanggil dari `bin/server.dart` dan dari test.
Future<HttpServer> serve({
  required String host,
  required int port,
  required Handler handler,
}) {
  return shelf_io.serve(handler, host, port);
}

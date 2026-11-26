import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../middleware/api_response.dart';

/// Merakit seluruh route.
///
/// `server.dart` hanya memanggil fungsi ini; penambahan fitur baru tidak boleh
/// mengubah entry point. Router sengaja stateless — tidak menyentuh variabel
/// global — supaya test bisa menjalankan beberapa instance secara paralel.
Router buildRouter() {
  final router = Router();

  // Liveness: dipakai health check, CI, dan Docker HEALTHCHECK.
  // Tidak menyentuh database, jadi tetap 200 walau DB sedang sibuk.
  router.get('/health', (Request request) {
    return ApiResponse.ok({
      'status': 'ok',
      'service': 'food-rescue-backend',
      'time': DateTime.now().toUtc().toIso8601String(),
    });
  });

  // Semua rute tak dikenal dijawab JSON, bukan halaman bawaan shelf.
  router.all('/<ignored|.*>', (Request request) {
    return ApiResponse.error(404, 'Endpoint tidak ditemukan.');
  });

  return router;
}

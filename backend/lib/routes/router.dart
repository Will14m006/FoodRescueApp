import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/jwt_service.dart';
import '../auth/login_throttle.dart';
import '../auth/password_hasher.dart';
import '../db/database.dart';
import '../media/photo_store.dart';
import '../media/uploads_handler.dart';
import '../middleware/api_response.dart';
import 'auth_routes.dart';
import 'admin_routes.dart';
import 'food_routes.dart';
import 'merchant_routes.dart';
import 'order_routes.dart';

/// Merakit seluruh route.
///
/// Semua dependensi (database, JWT, hasher) **disuntikkan**, bukan singleton
/// global. Test bisa menjalankan beberapa instance dengan database in-memory
/// berbeda secara paralel tanpa saling mengganggu.
Router buildRouter({
  required AppDatabase db,
  required JwtService jwt,
  required PasswordHasher hasher,
  required LoginThrottle throttle,
  required PhotoStore photos,
}) {
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

  router.mount(
    '/',
    authRoutes(db: db, jwt: jwt, hasher: hasher, throttle: throttle).call,
  );
  router.mount('/', merchantRoutes(db: db, jwt: jwt).call);
  router.mount('/', foodRoutes(db: db, jwt: jwt, photos: photos).call);
  router.mount('/', orderRoutes(db: db, jwt: jwt).call);
  router.mount('/', adminRoutes(db: db, jwt: jwt).call);

  // Foto menu. Sebelum catch-all 404, dan sengaja tanpa auth: katalog publik
  // harus bisa menampilkan gambar tanpa token.
  router.get(
    '/uploads/<name|.*>',
    (Request request) => serveUpload(
      directory: photos.directory,
      name: request.params['name'],
    ),
  );

  // Rute tak dikenal dijawab JSON, bukan halaman bawaan shelf.
  router.all('/<ignored|.*>', (Request request) {
    return ApiResponse.error(404, 'Endpoint tidak ditemukan.');
  });

  return router;
}

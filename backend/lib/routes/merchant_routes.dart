import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/jwt_service.dart';
import '../db/database.dart';
import '../middleware/api_response.dart';
import 'mappers.dart';

/// Profil toko milik user ber-role merchant.
///
/// Dipisah dari `/auth/register` supaya hanya ada **satu** jalan membuat
/// profil toko. Merchant baru: register → login → `PUT /merchants/me` → baru
/// bisa membuat makanan.
Router merchantRoutes({required AppDatabase db, required JwtService jwt}) {
  final router = Router();
  final merchantOnly = authGuard(jwt, roles: {UserRole.merchant});

  // Upsert: dipakai untuk membuat maupun mengubah nama toko.
  router.put(
    '/merchants/me',
    merchantOnly((Request request) async {
      final auth = authenticatedUser(request);
      final body = await readJsonObject(request);
      final storeName = requireString(body, 'storeName', maxLength: 160);

      final existing = await merchantOf(db, auth.id);

      final Merchant merchant;
      if (existing == null) {
        merchant = await db.into(db.merchants).insertReturning(
              MerchantsCompanion.insert(
                storeName: storeName,
                ownerId: auth.id,
              ),
            );
      } else {
        final updated = existing.copyWith(storeName: storeName);
        await db.update(db.merchants).replace(updated);
        merchant = updated;
      }

      return ApiResponse.ok({'merchant': merchantJson(merchant)});
    }),
  );

  router.get(
    '/merchants/me',
    merchantOnly((Request request) async {
      final auth = authenticatedUser(request);
      final merchant = await merchantOf(db, auth.id);
      if (merchant == null) {
        throw const ApiException(
          404,
          'Profil toko belum dibuat. Kirim PUT /merchants/me lebih dulu.',
          code: 'merchant_profile_missing',
        );
      }
      return ApiResponse.ok({'merchant': merchantJson(merchant)});
    }),
  );

  return router;
}

/// Toko milik user, atau `null` kalau belum punya.
Future<Merchant?> merchantOf(AppDatabase db, int ownerId) {
  return (db.select(db.merchants)
        ..where((t) => t.ownerId.equals(ownerId)))
      .getSingleOrNull();
}

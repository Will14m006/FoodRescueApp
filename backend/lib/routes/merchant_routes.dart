import 'package:drift/drift.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/jwt_service.dart';
import '../db/database.dart';
import '../middleware/api_response.dart';
import '../middleware/pagination.dart';
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

  /// Dashboard merchant: **semua** makanannya, termasuk yang nonaktif dan
  /// yang kuotanya sudah habis. Katalog publik (`GET /foods`) hanya menampilkan
  /// yang bisa dibeli, jadi merchant butuh jalan lain untuk mengelola stoknya.
  router.get(
    '/merchants/me/foods',
    merchantOnly((Request request) async {
      final auth = authenticatedUser(request);
      final merchant = await merchantOf(db, auth.id);
      if (merchant == null) {
        throw const ApiException(
          409,
          'Buat profil toko lebih dulu lewat PUT /merchants/me.',
          code: 'merchant_profile_missing',
        );
      }

      final page = readPagination(request);
      final rows = await (db.select(db.surplusFoods)
            ..where((t) => t.merchantId.equals(merchant.id))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(page.limit, offset: page.offset))
          .get();

      return ApiResponse.ok({
        'foods': rows
            .map((food) => foodJson(food, merchantName: merchant.storeName))
            .toList(),
        'count': rows.length,
        'limit': page.limit,
        'offset': page.offset,
      });
    }),
  );

  /// Ringkasan penjualan toko sendiri. Dihitung di SQL, bukan di Dart.
  router.get(
    '/merchants/me/stats',
    merchantOnly((Request request) async {
      final auth = authenticatedUser(request);
      final merchant = await merchantOf(db, auth.id);
      if (merchant == null) {
        throw const ApiException(
          409,
          'Buat profil toko lebih dulu lewat PUT /merchants/me.',
          code: 'merchant_profile_missing',
        );
      }

      final foods = await (db.select(db.surplusFoods)
            ..where((t) => t.merchantId.equals(merchant.id)))
          .get();
      final foodIds = foods.map((f) => f.id).toList();

      var total = 0;
      var pending = 0;
      var completed = 0;
      var cancelled = 0;
      var revenue = 0;
      var porsiTerjual = 0;

      if (foodIds.isNotEmpty) {
        final orders = await (db.select(db.orders)
              ..where((t) => t.foodId.isIn(foodIds)))
            .get();

        for (final order in orders) {
          total++;
          switch (order.status) {
            case OrderStatus.pending:
              pending++;
            case OrderStatus.completed:
              completed++;
            case OrderStatus.cancelled:
              cancelled++;
          }
          if (order.status != OrderStatus.cancelled) {
            revenue += order.totalPrice;
            porsiTerjual += order.quantity;
          }
        }
      }

      return ApiResponse.ok({
        'merchant': merchantJson(merchant),
        'foods': {
          'total': foods.length,
          'active': foods.where((f) => f.isActive).length,
          'remainingQuota':
              foods.where((f) => f.isActive).fold(0, (sum, f) => sum + f.quota),
        },
        'orders': {
          'total': total,
          'pending': pending,
          'completed': completed,
          'cancelled': cancelled,
          'revenue': revenue,
          'portionsSold': porsiTerjual,
        },
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
      });
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

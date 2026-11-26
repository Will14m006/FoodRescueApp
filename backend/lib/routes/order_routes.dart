import 'package:drift/drift.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/jwt_service.dart';
import '../db/database.dart';
import '../middleware/api_response.dart';
import '../orders/pickup_code.dart';
import 'mappers.dart';
import 'merchant_routes.dart';

/// Pesanan.
///
///   POST  /orders                  buyer, kuota dipotong transaksional
///   GET   /orders                  buyer: miliknya; merchant: tokonya; admin: semua
///   GET   /orders/<id>             pemilik / merchant toko / admin
///   POST  /orders/<id>/complete    merchant toko / admin, wajib kirim pickupCode
///   POST  /orders/<id>/cancel      pembeli / merchant toko / admin
///
/// Aturan (Architecture.md §5): pesanan **tidak pernah** dihapus dan tidak
/// pernah ditimpa. Batal = ubah status + kembalikan kuota, satu transaksi.
Router orderRoutes({required AppDatabase db, required JwtService jwt}) {
  final router = Router();
  final anyRole = authGuard(jwt);

  router.post(
    '/orders',
    authGuard(jwt, roles: {UserRole.buyer})((Request request) async {
      final auth = authenticatedUser(request);
      final body = await readJsonObject(request);

      final foodId = requireInt(body, 'foodId', min: 1, max: 1 << 31);
      final quantity = requireInt(body, 'quantity', min: 1, max: 100);

      final order = await createOrder(
        db,
        buyerId: auth.id,
        foodId: foodId,
        quantity: quantity,
      );

      return ApiResponse.created({
        'order': await orderJsonById(db, order.id),
      });
    }),
  );

  router.get(
    '/orders',
    anyRole((Request request) async {
      final auth = authenticatedUser(request);

      List<int>? allowedFoodIds;
      switch (auth.role) {
        case UserRole.buyer:
          break;
        case UserRole.merchant:
          final merchant = await merchantOf(db, auth.id);
          if (merchant == null) {
            return ApiResponse.ok({'orders': <Object>[], 'count': 0});
          }
          allowedFoodIds = await (db.select(db.surplusFoods)
                ..where((t) => t.merchantId.equals(merchant.id)))
              .map((t) => t.id)
              .get();
          if (allowedFoodIds.isEmpty) {
            return ApiResponse.ok({'orders': <Object>[], 'count': 0});
          }
        case UserRole.admin:
          break;
      }

      final statement = db.select(db.orders)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

      if (auth.role == UserRole.buyer) {
        statement.where((t) => t.buyerId.equals(auth.id));
      } else if (allowedFoodIds != null) {
        statement.where((t) => t.foodId.isIn(allowedFoodIds!));
      }

      final rows = await statement.get();
      final orders = <Map<String, dynamic>>[];
      for (final row in rows) {
        orders.add(await orderJsonById(db, row.id));
      }
      return ApiResponse.ok({'orders': orders, 'count': orders.length});
    }),
  );

  router.get(
    '/orders/<id>',
    anyRole((Request request) async {
      final auth = authenticatedUser(request);
      final orderId = int.tryParse(request.params['id'] ?? '');

      final order =
          orderId == null ? null : await _orderById(db, orderId);
      if (order == null || !await mayView(db, auth, order)) {
        throw const ApiException(404, 'Pesanan tidak ditemukan.');
      }
      return ApiResponse.ok({'order': await orderJsonById(db, orderId!)});
    }),
  );

  // Merchant memvalidasi kode pick-up saat pembeli mengambil makanan.
  router.post(
    '/orders/<id>/complete',
    authGuard(jwt, roles: {UserRole.merchant, UserRole.admin})(
      (Request request) async {
        final auth = authenticatedUser(request);
        final body = await readJsonObject(request);

        // Kode wajib dikirim ulang: merchant harus benar-benar membaca kode
        // dari pembeli, bukan sekadar menekan tombol pada pesanan mana pun.
        final code = requireString(body, 'pickupCode', maxLength: 40);
        final orderId = int.tryParse(request.params['id'] ?? '');

        final order =
            orderId == null ? null : await _orderById(db, orderId);
        if (order == null || !await mayView(db, auth, order)) {
          throw const ApiException(404, 'Pesanan tidak ditemukan.');
        }
        if (order.status != OrderStatus.pending) {
          throw const ApiException(
            409,
            'Hanya pesanan berstatus pending yang bisa diselesaikan.',
            code: 'invalid_status',
          );
        }
        if (order.pickupCode != code.trim().toUpperCase()) {
          throw const ApiException(
            422,
            'Kode pick-up tidak cocok dengan pesanan ini.',
            code: 'pickup_code_mismatch',
          );
        }

        await db.update(db.orders).replace(
              order.copyWith(status: OrderStatus.completed),
            );
        return ApiResponse.ok({'order': await orderJsonById(db, orderId!)});
      },
    ),
  );

  router.post(
    '/orders/<id>/cancel',
    anyRole((Request request) async {
      final auth = authenticatedUser(request);
      final orderId = int.tryParse(request.params['id'] ?? '');

      final order =
          orderId == null ? null : await _orderById(db, orderId);
      if (order == null || !await mayView(db, auth, order)) {
        throw const ApiException(404, 'Pesanan tidak ditemukan.');
      }
      if (order.status != OrderStatus.pending) {
        throw const ApiException(
          409,
          'Hanya pesanan berstatus pending yang bisa dibatalkan.',
          code: 'invalid_status',
        );
      }

      // Status dan pengembalian kuota harus terjadi bersama: kalau salah satu
      // gagal, kuota bisa hilang atau dobel.
      await db.transaction(() async {
        final changed = await _setStatus(
          db,
          orderId: orderId!,
          from: OrderStatus.pending,
          to: OrderStatus.cancelled,
        );
        if (!changed) {
          throw const ApiException(
            409,
            'Pesanan sudah berubah status. Muat ulang halaman.',
            code: 'invalid_status',
          );
        }
        await (db.update(db.surplusFoods)
              ..where((t) => t.id.equals(order.foodId)))
            .write(
          SurplusFoodsCompanion.custom(
            quota: db.surplusFoods.quota + Variable<int>(order.quantity),
          ),
        );
      });

      return ApiResponse.ok({'order': await orderJsonById(db, orderId!)});
    }),
  );

  return router;
}

/// Inti sesi ini: potong kuota **dan** buat pesanan dalam satu transaksi.
///
/// Pemotongan memakai `UPDATE … WHERE quota >= ?`, jadi cek dan tulis terjadi
/// di satu statement. Dua pembeli yang berebut unit terakhir tidak bisa
/// sama-sama menang: yang kedua mendapat 0 baris terpengaruh.
Future<Order> createOrder(
  AppDatabase db, {
  required int buyerId,
  required int foodId,
  required int quantity,
}) {
  return db.transaction(() async {
    final food = await (db.select(db.surplusFoods)
          ..where((t) => t.id.equals(foodId)))
        .getSingleOrNull();

    if (food == null || !food.isActive) {
      throw const ApiException(404, 'Makanan tidak ditemukan.');
    }
    if (food.quota < quantity) {
      throw ApiException(
        409,
        'Kuota tersisa ${food.quota}, tidak cukup untuk $quantity porsi.',
        code: 'insufficient_quota',
      );
    }

    final reserved = await (db.update(db.surplusFoods)
          ..where((t) => t.id.equals(foodId))
          ..where((t) => t.quota.isBiggerOrEqualValue(quantity)))
        .write(
      SurplusFoodsCompanion.custom(
        quota: db.surplusFoods.quota - Variable<int>(quantity),
      ),
    );

    if (reserved == 0) {
      // Kalah balapan dengan request lain di antara SELECT dan UPDATE.
      throw const ApiException(
        409,
        'Kuota baru saja habis. Silakan pilih makanan lain.',
        code: 'insufficient_quota',
      );
    }

    final totalPrice = food.discountPrice * quantity;

    // PickupCode unik di seluruh tabel. Tabrakan sangat jarang, tapi kalau
    // terjadi harus dicoba ulang, bukan gagal 500.
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        return await db.into(db.orders).insertReturning(
              OrdersCompanion.insert(
                buyerId: buyerId,
                foodId: foodId,
                quantity: quantity,
                totalPrice: totalPrice,
                pickupCode: PickupCode.generate(),
              ),
            );
      } catch (_) {
        if (attempt >= PickupCode.maxAttempts) rethrow;
      }
    }
  });
}

/// Ubah status hanya kalau status saat ini masih [from].
///
/// `false` berarti request lain lebih dulu mengubahnya.
Future<bool> _setStatus(
  AppDatabase db, {
  required int orderId,
  required OrderStatus from,
  required OrderStatus to,
}) async {
  final changed = await (db.update(db.orders)
        ..where((t) => t.id.equals(orderId))
        ..where((t) => t.status.equalsValue(from)))
      .write(OrdersCompanion(status: Value(to)));
  return changed > 0;
}

Future<Order?> _orderById(AppDatabase db, int id) {
  return (db.select(db.orders)..where((t) => t.id.equals(id)))
      .getSingleOrNull();
}

/// Pembeli hanya boleh melihat pesanannya sendiri; merchant hanya pesanan di
/// tokonya; admin semua. Selain itu 404 (bukan 403) supaya keberadaan pesanan
/// orang lain tidak bocor.
Future<bool> mayView(AppDatabase db, AuthUser auth, Order order) async {
  switch (auth.role) {
    case UserRole.admin:
      return true;
    case UserRole.buyer:
      return order.buyerId == auth.id;
    case UserRole.merchant:
      final merchant = await merchantOf(db, auth.id);
      if (merchant == null) return false;
      final food = await (db.select(db.surplusFoods)
            ..where((t) => t.id.equals(order.foodId)))
          .getSingleOrNull();
      return food != null && food.merchantId == merchant.id;
  }
}

/// Merakit JSON pesanan lengkap dengan nama pembeli, makanan, dan toko.
Future<Map<String, dynamic>> orderJsonById(
  AppDatabase db,
  int orderId,
) async {
  final order = await _orderById(db, orderId);
  if (order == null) throw StateError('Order $orderId hilang setelah dibuat.');

  final buyer = await (db.select(db.users)
        ..where((t) => t.id.equals(order.buyerId)))
      .getSingleOrNull();

  final food = await (db.select(db.surplusFoods)
        ..where((t) => t.id.equals(order.foodId)))
      .getSingleOrNull();

  final merchant = food == null
      ? null
      : await (db.select(db.merchants)
            ..where((t) => t.id.equals(food.merchantId)))
          .getSingleOrNull();

  return orderJson(
    order,
    buyerName: buyer?.name ?? 'Pembeli',
    foodName: food?.name ?? 'Makanan surplus',
    merchantName: merchant?.storeName ?? 'Mitra Food Rescue',
  );
}

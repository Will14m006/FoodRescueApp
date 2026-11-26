import 'package:drift/drift.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/jwt_service.dart';
import '../db/database.dart';
import '../middleware/api_response.dart';
import 'mappers.dart';
import 'merchant_routes.dart';

/// Katalog surplus.
///
///   GET    /foods            publik, hanya yang aktif & masih ada kuota
///   GET    /foods/<id>       publik
///   POST   /foods            merchant (butuh profil toko)
///   PATCH  /foods/<id>       merchant pemilik
///   DELETE /foods/<id>       merchant pemilik → `isActive = false`
///
/// Food **tidak pernah** dihapus dari tabel: pesanan lama harus tetap bisa
/// menunjuk ke makanannya (Architecture.md §5).
Router foodRoutes({required AppDatabase db, required JwtService jwt}) {
  final router = Router();
  final merchantOnly = authGuard(jwt, roles: {UserRole.merchant});

  router.get('/foods', (Request request) async {
    final query = request.url.queryParameters['q']?.trim().toLowerCase();

    final statement = db.select(db.surplusFoods)
      ..where((t) => t.isActive.equals(true))
      ..where((t) => t.quota.isBiggerThanValue(0))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    final rows = await statement.get();
    final names = await merchantNames(db, rows.map((r) => r.merchantId));

    final foods = rows
        .where((food) {
          if (query == null || query.isEmpty) return true;
          final merchant = names[food.merchantId] ?? '';
          return food.name.toLowerCase().contains(query) ||
              merchant.toLowerCase().contains(query);
        })
        .map((food) => foodJson(
              food,
              merchantName: names[food.merchantId] ?? 'Mitra Food Rescue',
            ))
        .toList();

    return ApiResponse.ok({'foods': foods, 'count': foods.length});
  });

  router.get('/foods/<id>', (Request request) async {
    final food = await _foodById(db, request.params['id']);
    if (food == null) {
      throw const ApiException(404, 'Makanan tidak ditemukan.');
    }

    final merchant = await _merchantById(db, food.merchantId);
    return ApiResponse.ok({
      'food': foodJson(
        food,
        merchantName: merchant?.storeName ?? 'Mitra Food Rescue',
      ),
    });
  });

  router.post(
    '/foods',
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

      final body = await readJsonObject(request);
      final input = _FoodInput.parse(body);

      final food = await db.into(db.surplusFoods).insertReturning(
            SurplusFoodsCompanion.insert(
              merchantId: merchant.id,
              name: input.name,
              description: Value(input.description),
              originalPrice: input.originalPrice,
              discountPrice: input.discountPrice,
              quota: input.quota,
              pickupWindow: input.pickupWindow,
            ),
          );

      return ApiResponse.created({
        'food': foodJson(food, merchantName: merchant.storeName),
      });
    }),
  );

  router.patch(
    '/foods/<id>',
    merchantOnly((Request request) async {
      final auth = authenticatedUser(request);
      final food = await _ownedFood(db, auth.id, request.params['id']);
      final body = await readJsonObject(request);

      final updated = food.copyWith(
        name: _optionalString(body, 'name', maxLength: 160) ?? food.name,
        description:
            _optionalString(body, 'description', maxLength: 2000) ??
                food.description,
        originalPrice:
            _optionalInt(body, 'originalPrice', min: 1, max: 100000000) ??
                food.originalPrice,
        discountPrice:
            _optionalInt(body, 'discountPrice', min: 1, max: 100000000) ??
                food.discountPrice,
        quota: _optionalInt(body, 'quota', min: 0, max: 10000) ?? food.quota,
        pickupWindow:
            _optionalString(body, 'pickupWindow', maxLength: 120) ??
                food.pickupWindow,
        isActive: _optionalBool(body, 'isActive') ?? food.isActive,
      );

      if (updated.discountPrice > updated.originalPrice) {
        throw const ApiException(
          422,
          'Harga diskon tidak boleh lebih besar dari harga asli.',
          code: 'invalid_discountPrice',
        );
      }

      await db.update(db.surplusFoods).replace(updated);
      final merchant = await _merchantById(db, updated.merchantId);

      return ApiResponse.ok({
        'food': foodJson(
          updated,
          merchantName: merchant?.storeName ?? 'Mitra Food Rescue',
        ),
      });
    }),
  );

  // Soft delete: pesanan lama tetap menunjuk baris yang sama.
  router.delete(
    '/foods/<id>',
    merchantOnly((Request request) async {
      final auth = authenticatedUser(request);
      final food = await _ownedFood(db, auth.id, request.params['id']);

      final updated = food.copyWith(isActive: false);
      await db.update(db.surplusFoods).replace(updated);
      final merchant = await _merchantById(db, updated.merchantId);

      return ApiResponse.ok({
        'food': foodJson(
          updated,
          merchantName: merchant?.storeName ?? 'Mitra Food Rescue',
        ),
      });
    }),
  );

  return router;
}

/// Makanan milik merchant pemanggil. 404 (bukan 403) kalau bukan miliknya —
/// supaya keberadaan id makanan orang lain tidak bocor.
Future<SurplusFood> _ownedFood(
  AppDatabase db,
  int ownerId,
  String? rawId,
) async {
  final foodId = int.tryParse(rawId ?? '');
  if (foodId == null) {
    throw const ApiException(404, 'Makanan tidak ditemukan.');
  }

  final merchant = await merchantOf(db, ownerId);
  if (merchant == null) {
    throw const ApiException(
      409,
      'Buat profil toko lebih dulu lewat PUT /merchants/me.',
      code: 'merchant_profile_missing',
    );
  }

  final food = await _foodById(db, rawId);
  if (food == null || food.merchantId != merchant.id) {
    throw const ApiException(404, 'Makanan tidak ditemukan.');
  }
  return food;
}

Future<SurplusFood?> _foodById(AppDatabase db, String? rawId) {
  final foodId = int.tryParse(rawId ?? '');
  if (foodId == null) return Future.value(null);
  return (db.select(db.surplusFoods)..where((t) => t.id.equals(foodId)))
      .getSingleOrNull();
}

Future<Merchant?> _merchantById(AppDatabase db, int id) {
  return (db.select(db.merchants)..where((t) => t.id.equals(id)))
      .getSingleOrNull();
}

/// Satu query untuk semua merchant yang terlibat, bukan N+1.
Future<Map<int, String>> merchantNames(
  AppDatabase db,
  Iterable<int> ids,
) async {
  final unique = ids.toSet().toList();
  if (unique.isEmpty) return const {};

  final rows = await (db.select(db.merchants)
        ..where((t) => t.id.isIn(unique)))
      .get();
  return {for (final row in rows) row.id: row.storeName};
}

/// Input pembuatan makanan, sudah tervalidasi.
class _FoodInput {
  const _FoodInput({
    required this.name,
    required this.description,
    required this.originalPrice,
    required this.discountPrice,
    required this.quota,
    required this.pickupWindow,
  });

  final String name;
  final String description;
  final int originalPrice;
  final int discountPrice;
  final int quota;
  final String pickupWindow;

  factory _FoodInput.parse(Map<String, dynamic> body) {
    final description =
        (body['description'] is String ? body['description'] as String : '')
            .trim();
    if (description.length > 2000) {
      throw const ApiException(
        422,
        'Field "description" maksimal 2000 karakter.',
        code: 'invalid_description',
      );
    }

    final input = _FoodInput(
      name: requireString(body, 'name', maxLength: 160),
      description: description,
      originalPrice: requireInt(
        body,
        'originalPrice',
        min: 1,
        max: 100000000,
      ),
      discountPrice: requireInt(
        body,
        'discountPrice',
        min: 1,
        max: 100000000,
      ),
      quota: requireInt(body, 'quota', min: 1, max: 10000),
      pickupWindow: requireString(body, 'pickupWindow', maxLength: 120),
    );

    if (input.discountPrice > input.originalPrice) {
      throw const ApiException(
        422,
        'Harga diskon tidak boleh lebih besar dari harga asli.',
        code: 'invalid_discountPrice',
      );
    }
    return input;
  }
}

String? _optionalString(
  Map<String, dynamic> body,
  String key, {
  required int maxLength,
}) {
  if (!body.containsKey(key)) return null;
  return requireString(body, key, maxLength: maxLength);
}

int? _optionalInt(
  Map<String, dynamic> body,
  String key, {
  required int min,
  required int max,
}) {
  if (!body.containsKey(key)) return null;
  return requireInt(body, key, min: min, max: max);
}

bool? _optionalBool(Map<String, dynamic> body, String key) {
  if (!body.containsKey(key)) return null;
  final value = body[key];
  if (value is! bool) {
    throw ApiException(
      422,
      'Field "$key" harus true/false.',
      code: 'invalid_$key',
    );
  }
  return value;
}

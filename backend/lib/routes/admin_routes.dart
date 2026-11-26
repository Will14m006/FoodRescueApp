import 'package:drift/drift.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/jwt_service.dart';
import '../db/database.dart';
import '../middleware/api_response.dart';
import '../middleware/pagination.dart';
import 'mappers.dart';
import 'order_routes.dart';

/// Endpoint khusus admin.
///
/// Admin **tidak** bisa dibuat lewat HTTP (lihat `auth_routes.dart`) dan tidak
/// bisa menaikkan peran dirinya sendiri lewat API: pembuatan/promosi admin
/// hanya lewat `tool/seed.dart` yang dijalankan di mesin server.
Router adminRoutes({required AppDatabase db, required JwtService jwt}) {
  final router = Router();
  final adminOnly = authGuard(jwt, roles: {UserRole.admin});

  /// Daftar user tanpa `passwordHash`, dengan paginasi.
  ///
  /// `?role=merchant` memfilter; nilai role tak dikenal → 422 agar salah ketik
  /// tidak menghasilkan daftar kosong yang membingungkan.
  router.get(
    '/admin/users',
    adminOnly((Request request) async {
      final page = readPagination(request);
      final roleParam = request.url.queryParameters['role']?.trim();
      final search = request.url.queryParameters['q']?.trim().toLowerCase();

      UserRole? role;
      if (roleParam != null && roleParam.isNotEmpty) {
        role = _roleFromName(roleParam);
        if (role == null) {
          throw const ApiException(
            422,
            'Parameter "role" harus buyer, merchant, atau admin.',
            code: 'invalid_role',
          );
        }
      }

      final statement = db.select(db.users)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
      if (role != null) {
        statement.where((t) => t.role.equalsValue(role!));
      }
      if (search != null && search.isNotEmpty) {
        statement.where(
          (t) => t.email.lower().contains(search) | t.name.lower().contains(search),
        );
      }

      // Total dihitung tanpa LIMIT supaya UI bisa menampilkan "x dari y".
      final all = await statement.get();
      final pageRows = all.skip(page.offset).take(page.limit).toList();

      return ApiResponse.ok({
        'users': pageRows.map(userJson).toList(),
        'count': pageRows.length,
        'total': all.length,
        'limit': page.limit,
        'offset': page.offset,
      });
    }),
  );

  /// Detail satu user + jumlah pesanannya. Dipakai halaman detail admin.
  router.get(
    '/admin/users/<id>',
    adminOnly((Request request) async {
      final user = await _userById(db, request.params['id']);
      if (user == null) {
        throw const ApiException(404, 'Pengguna tidak ditemukan.');
      }

      final orderCount = await (db.selectOnly(db.orders)
            ..addColumns([countAll()])
            ..where(db.orders.buyerId.equals(user.id)))
          .getSingle()
          .then((row) => row.read(countAll()) ?? 0);

      final spent = await (db.selectOnly(db.orders)
            ..addColumns([db.orders.totalPrice.sum()])
            ..where(db.orders.buyerId.equals(user.id))
            ..where(db.orders.status.equalsValue(OrderStatus.cancelled).not()))
          .getSingle()
          .then((row) => row.read(db.orders.totalPrice.sum()) ?? 0);

      return ApiResponse.ok({
        'user': userJson(user),
        'stats': {
          'orders': orderCount,
          'spent': spent,
        },
      });
    }),
  );

  /// Tangguhkan / aktifkan akun.
  ///
  /// Hanya `isActive` yang bisa diubah — peran tetap hanya lewat seed CLI,
  /// karena menaikkan peran lewat API berarti siapa pun yang mencuri token
  /// admin bisa mencetak admin baru.
  router.patch(
    '/admin/users/<id>',
    adminOnly((Request request) async {
      final auth = authenticatedUser(request);
      final user = await _userById(db, request.params['id']);
      if (user == null) {
        throw const ApiException(404, 'Pengguna tidak ditemukan.');
      }

      const forbidden = {'role', 'password', 'passwordHash', 'email', 'id'};
      final body = await readJsonObject(request);
      final attempted = forbidden.where(body.containsKey).toList();
      if (attempted.isNotEmpty) {
        throw ApiException(
          422,
          'Field tidak bisa diubah dari sini: ${attempted.join(', ')}.',
          code: 'immutable_field',
        );
      }

      final isActive = body['isActive'];
      if (isActive is! bool) {
        throw const ApiException(
          422,
          'Field "isActive" wajib true/false.',
          code: 'invalid_isActive',
        );
      }

      // Admin tidak boleh mengunci dirinya sendiri: satu-satunya jalan keluar
      // adalah seed CLI di mesin server, yang tidak selalu tersedia saat demo.
      if (user.id == auth.id && !isActive) {
        throw const ApiException(
          409,
          'Kamu tidak bisa menangguhkan akunmu sendiri.',
          code: 'self_suspend',
        );
      }

      final updated = user.copyWith(isActive: isActive);
      await db.update(db.users).replace(updated);

      return ApiResponse.ok({'user': userJson(updated)});
    }),
  );

  /// Semua makanan lintas toko, termasuk yang nonaktif.
  router.get(
    '/admin/foods',
    adminOnly((Request request) async {
      final page = readPagination(request);
      final activeOnly = request.url.queryParameters['active'];

      final statement = db.select(db.surplusFoods)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
      if (activeOnly == 'true') {
        statement.where((t) => t.isActive.equals(true));
      } else if (activeOnly == 'false') {
        statement.where((t) => t.isActive.equals(false));
      }

      final all = await statement.get();
      final pageRows = all.skip(page.offset).take(page.limit).toList();

      final names = await _merchantNames(db, pageRows.map((f) => f.merchantId));

      return ApiResponse.ok({
        'foods': pageRows
            .map((food) => foodJson(
                  food,
                  merchantName: names[food.merchantId] ?? 'Mitra Food Rescue',
                ))
            .toList(),
        'count': pageRows.length,
        'total': all.length,
        'limit': page.limit,
        'offset': page.offset,
      });
    }),
  );

  /// Semua pesanan lintas toko, dengan filter status.
  router.get(
    '/admin/orders',
    adminOnly((Request request) async {
      final page = readPagination(request);
      final statusParam = request.url.queryParameters['status']?.trim();

      OrderStatus? status;
      if (statusParam != null && statusParam.isNotEmpty) {
        status = _statusFromName(statusParam);
        if (status == null) {
          throw const ApiException(
            422,
            'Parameter "status" harus pending, completed, atau cancelled.',
            code: 'invalid_status',
          );
        }
      }

      final statement = db.select(db.orders)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
      if (status != null) {
        statement.where((t) => t.status.equalsValue(status!));
      }

      final all = await statement.get();
      final pageRows = all.skip(page.offset).take(page.limit).toList();

      final orders = <Map<String, dynamic>>[];
      for (final row in pageRows) {
        orders.add(await orderJsonById(db, row.id));
      }

      return ApiResponse.ok({
        'orders': orders,
        'count': orders.length,
        'total': all.length,
        'limit': page.limit,
        'offset': page.offset,
      });
    }),
  );

  /// Angka ringkas untuk dashboard admin.
  ///
  /// Semua dihitung di SQL (`COUNT`/`SUM`), bukan dengan menarik seluruh tabel
  /// ke memori — tetap murah saat data bertambah.
  router.get(
    '/admin/stats',
    adminOnly((Request request) async {
      final totalUsers = await _count(db, db.users);
      final buyers = await _count(db, db.users,
          where: db.users.role.equalsValue(UserRole.buyer));
      final merchants = await _count(db, db.users,
          where: db.users.role.equalsValue(UserRole.merchant));
      final admins = await _count(db, db.users,
          where: db.users.role.equalsValue(UserRole.admin));
      final suspended = await _count(db, db.users,
          where: db.users.isActive.equals(false));

      final stores = await _count(db, db.merchants);
      final activeFoods = await _count(db, db.surplusFoods,
          where: db.surplusFoods.isActive.equals(true));
      final remainingQuota = await _sum(db, db.surplusFoods.quota,
          table: db.surplusFoods,
          where: db.surplusFoods.isActive.equals(true));

      final totalOrders = await _count(db, db.orders);
      final pendingOrders = await _count(db, db.orders,
          where: db.orders.status.equalsValue(OrderStatus.pending));
      final completedOrders = await _count(db, db.orders,
          where: db.orders.status.equalsValue(OrderStatus.completed));
      final cancelledOrders = await _count(db, db.orders,
          where: db.orders.status.equalsValue(OrderStatus.cancelled));

      // Pesanan batal tidak dihitung sebagai pendapatan.
      final revenue = await _sum(db, db.orders.totalPrice,
          table: db.orders,
          where: db.orders.status.equalsValue(OrderStatus.cancelled).not());

      // Berapa porsi yang benar-benar terselamatkan (bukan dibatalkan).
      final portionsSaved = await (db.selectOnly(db.orders)
            ..addColumns([db.orders.quantity.sum()])
            ..where(db.orders.status.equalsValue(OrderStatus.cancelled).not()))
          .getSingle()
          .then((row) => row.read(db.orders.quantity.sum()) ?? 0);

      return ApiResponse.ok({
        'users': {
          'total': totalUsers,
          'buyer': buyers,
          'merchant': merchants,
          'admin': admins,
          'suspended': suspended,
        },
        'merchants': {'total': stores},
        'foods': {
          'active': activeFoods,
          'remainingQuota': remainingQuota,
        },
        'orders': {
          'total': totalOrders,
          'pending': pendingOrders,
          'completed': completedOrders,
          'cancelled': cancelledOrders,
          'revenue': revenue,
          'portionsSaved': portionsSaved,
        },
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
      });
    }),
  );

  return router;
}

Future<User?> _userById(AppDatabase db, String? rawId) {
  final id = int.tryParse(rawId ?? '');
  if (id == null) return Future.value(null);
  return (db.select(db.users)..where((t) => t.id.equals(id))).getSingleOrNull();
}

Future<Map<int, String>> _merchantNames(
  AppDatabase db,
  Iterable<int> ids,
) async {
  final unique = ids.toSet().toList();
  if (unique.isEmpty) return const {};
  final rows =
      await (db.select(db.merchants)..where((t) => t.id.isIn(unique))).get();
  return {for (final row in rows) row.id: row.storeName};
}

UserRole? _roleFromName(String name) {
  final lower = name.trim().toLowerCase();
  for (final role in UserRole.values) {
    if (role.name == lower) return role;
  }
  return null;
}

OrderStatus? _statusFromName(String name) {
  final lower = name.trim().toLowerCase();
  for (final status in OrderStatus.values) {
    if (status.name == lower) return status;
  }
  return null;
}

Future<int> _count(
  AppDatabase db,
  TableInfo table, {
  Expression<bool>? where,
}) async {
  final expression = countAll();
  final query = db.selectOnly(table)..addColumns([expression]);
  if (where != null) query.where(where);
  final row = await query.getSingle();
  return row.read(expression) ?? 0;
}

Future<int> _sum(
  AppDatabase db,
  Expression<int> column, {
  Expression<bool>? where,
  required TableInfo table,
}) async {
  final expression = column.sum();
  final query = db.selectOnly(table)..addColumns([expression]);
  if (where != null) query.where(where);
  final row = await query.getSingle();
  return row.read(expression) ?? 0;
}

import 'package:drift/drift.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/jwt_service.dart';
import '../db/database.dart';
import '../middleware/api_response.dart';
import '../middleware/pagination.dart';
import 'mappers.dart';

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
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
        ..limit(page.limit, offset: page.offset);
      if (role != null) {
        statement.where((t) => t.role.equalsValue(role!));
      }

      final rows = await statement.get();
      return ApiResponse.ok({
        'users': rows.map(userJson).toList(),
        'count': rows.length,
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

      return ApiResponse.ok({
        'users': {
          'total': totalUsers,
          'buyer': buyers,
          'merchant': merchants,
          'admin': admins,
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
        },
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
      });
    }),
  );

  return router;
}

UserRole? _roleFromName(String name) {
  final lower = name.trim().toLowerCase();
  for (final role in UserRole.values) {
    if (role.name == lower) return role;
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

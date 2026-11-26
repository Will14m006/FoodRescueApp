import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/order_model.dart';
import '../models/surplus_food_model.dart';
import '../models/user_role.dart';

/// Angka ringkas `GET /admin/stats`.
class AdminStats {
  final int totalUsers;
  final int buyers;
  final int merchants;
  final int admins;
  final int stores;
  final int activeFoods;
  final int remainingQuota;
  final int totalOrders;
  final int pendingOrders;
  final int completedOrders;
  final int cancelledOrders;
  final int revenue;

  const AdminStats({
    required this.totalUsers,
    required this.buyers,
    required this.merchants,
    required this.admins,
    required this.stores,
    required this.activeFoods,
    required this.remainingQuota,
    required this.totalOrders,
    required this.pendingOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.revenue,
    this.suspended = 0,
    this.portionsSaved = 0,
  });

  /// Akun yang ditangguhkan admin.
  final int suspended;

  /// Total porsi yang benar-benar terselamatkan (pesanan tidak batal).
  final int portionsSaved;

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    final users = json['users'];
    final merchants = json['merchants'];
    final foods = json['foods'];
    final orders = json['orders'];
    if (users is! Map || merchants is! Map || foods is! Map || orders is! Map) {
      throw const ApiException('Statistik admin tidak valid.');
    }

    int pick(Map source, String key) => source[key] as int? ?? 0;

    return AdminStats(
      totalUsers: pick(users, 'total'),
      buyers: pick(users, 'buyer'),
      merchants: pick(users, 'merchant'),
      admins: pick(users, 'admin'),
      stores: pick(merchants, 'total'),
      activeFoods: pick(foods, 'active'),
      remainingQuota: pick(foods, 'remainingQuota'),
      totalOrders: pick(orders, 'total'),
      pendingOrders: pick(orders, 'pending'),
      completedOrders: pick(orders, 'completed'),
      cancelledOrders: pick(orders, 'cancelled'),
      revenue: pick(orders, 'revenue'),
      suspended: pick(users, 'suspended'),
      portionsSaved: pick(orders, 'portionsSaved'),
    );
  }
}

/// Satu baris daftar user admin. **Tidak** ada `passwordHash` — backend tidak
/// pernah mengirimkannya, dan model ini juga tidak punya tempat untuk itu.
class AdminUser {
  final int id;
  final String name;
  final String email;
  final UserRole role;
  final DateTime? createdAt;
  final bool isActive;

  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.createdAt,
    this.isActive = true,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! int) throw const ApiException('Data user tidak valid.');

    return AdminUser(
      id: id,
      name: (json['name'] as String?)?.trim() ?? 'Pengguna',
      email: json['email'] as String? ?? '',
      role: UserRole.fromName(json['role'] as String?),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

abstract class AdminRepository {
  Future<AdminStats> stats({required String token});
  Future<List<AdminUser>> users({
    required String token,
    UserRole? role,
    String? query,
  });

  /// Tangguhkan (`false`) atau aktifkan kembali (`true`) akun.
  Future<AdminUser> setUserActive({
    required String token,
    required int userId,
    required bool isActive,
  });

  /// Semua makanan lintas toko (termasuk nonaktif).
  Future<List<SurplusFood>> foods({required String token});

  /// Semua pesanan lintas toko, opsional filter status.
  Future<List<Order>> orders({required String token, OrderStatus? status});
}

class ApiAdminRepository implements AdminRepository {
  ApiAdminRepository({required this.api});

  final ApiClient api;

  @override
  Future<AdminStats> stats({required String token}) async {
    final body =
        await api.request(method: 'GET', path: '/admin/stats', token: token);
    return AdminStats.fromJson(body);
  }

  @override
  Future<List<AdminUser>> users({
    required String token,
    UserRole? role,
    String? query,
  }) async {
    final body = await api.request(
      method: 'GET',
      path: '/admin/users',
      token: token,
      query: {
        'limit': '200',
        if (role != null) 'role': role.name,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );

    final users = body['users'];
    if (users is! List) {
      throw const ApiException('Format daftar user tidak sesuai.');
    }
    return users
        .whereType<Map<String, dynamic>>()
        .map(AdminUser.fromJson)
        .toList();
  }

  @override
  Future<AdminUser> setUserActive({
    required String token,
    required int userId,
    required bool isActive,
  }) async {
    final body = await api.request(
      method: 'PATCH',
      path: '/admin/users/$userId',
      token: token,
      body: {'isActive': isActive},
    );
    final user = body['user'];
    if (user is! Map<String, dynamic>) {
      throw const ApiException('Respons admin tidak sesuai.');
    }
    return AdminUser.fromJson(user);
  }

  @override
  Future<List<SurplusFood>> foods({required String token}) async {
    final body = await api.request(
      method: 'GET',
      path: '/admin/foods',
      token: token,
      query: {'limit': '200'},
    );
    final foods = body['foods'];
    if (foods is! List) {
      throw const ApiException('Format daftar makanan tidak sesuai.');
    }
    return foods
        .whereType<Map<String, dynamic>>()
        .map(SurplusFood.fromJson)
        .toList();
  }

  @override
  Future<List<Order>> orders({
    required String token,
    OrderStatus? status,
  }) async {
    final body = await api.request(
      method: 'GET',
      path: '/admin/orders',
      token: token,
      query: {
        'limit': '200',
        if (status != null) 'status': status.jsonValue,
      },
    );
    final orders = body['orders'];
    if (orders is! List) {
      throw const ApiException('Format daftar pesanan tidak sesuai.');
    }
    return orders
        .whereType<Map<String, dynamic>>()
        .map(Order.fromJson)
        .toList();
  }
}

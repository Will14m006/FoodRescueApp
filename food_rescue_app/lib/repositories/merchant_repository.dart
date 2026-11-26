import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/surplus_food_model.dart';

class MerchantProfile {
  final int id;
  final String storeName;

  const MerchantProfile({required this.id, required this.storeName});

  factory MerchantProfile.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final storeName = json['storeName'];
    if (id is! int || storeName is! String || storeName.trim().isEmpty) {
      throw const ApiException('Profil toko tidak valid.');
    }
    return MerchantProfile(id: id, storeName: storeName.trim());
  }
}

/// Angka ringkas dashboard merchant (`GET /merchants/me/stats`).
class MerchantStats {
  final int totalFoods;
  final int activeFoods;
  final int remainingQuota;
  final int totalOrders;
  final int pendingOrders;
  final int completedOrders;
  final int cancelledOrders;
  final int revenue;
  final int portionsSold;

  const MerchantStats({
    required this.totalFoods,
    required this.activeFoods,
    required this.remainingQuota,
    required this.totalOrders,
    required this.pendingOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.revenue,
    required this.portionsSold,
  });

  factory MerchantStats.fromJson(Map<String, dynamic> json) {
    final foods = json['foods'];
    final orders = json['orders'];
    if (foods is! Map || orders is! Map) {
      throw const ApiException('Statistik toko tidak valid.');
    }

    int pick(Map source, String key) => source[key] as int? ?? 0;

    return MerchantStats(
      totalFoods: pick(foods, 'total'),
      activeFoods: pick(foods, 'active'),
      remainingQuota: pick(foods, 'remainingQuota'),
      totalOrders: pick(orders, 'total'),
      pendingOrders: pick(orders, 'pending'),
      completedOrders: pick(orders, 'completed'),
      cancelledOrders: pick(orders, 'cancelled'),
      revenue: pick(orders, 'revenue'),
      portionsSold: pick(orders, 'portionsSold'),
    );
  }
}

abstract class MerchantRepository {
  Future<MerchantProfile?> profile({required String token});

  /// Buat atau ubah nama toko (`PUT /merchants/me`).
  Future<MerchantProfile> saveProfile({
    required String token,
    required String storeName,
  });

  /// Semua makanan toko sendiri, termasuk yang nonaktif/kuota 0.
  Future<List<SurplusFood>> myFoods({required String token});

  Future<MerchantStats> stats({required String token});

  Future<SurplusFood> createFood({
    required String token,
    required String name,
    required String description,
    required int originalPrice,
    required int discountPrice,
    required int quota,
    required String pickupWindow,
  });

  Future<SurplusFood> updateQuota({
    required String token,
    required int foodId,
    required int quota,
  });
}

class ApiMerchantRepository implements MerchantRepository {
  ApiMerchantRepository({required this.api});

  final ApiClient api;

  @override
  Future<MerchantProfile?> profile({required String token}) async {
    try {
      final body =
          await api.request(method: 'GET', path: '/merchants/me', token: token);
      final merchant = body['merchant'];
      if (merchant is! Map<String, dynamic>) return null;
      return MerchantProfile.fromJson(merchant);
    } on ApiException catch (e) {
      // 404 = belum punya profil toko; itu bukan kesalahan.
      if (e.statusCode == 404 || e.statusCode == 409) return null;
      rethrow;
    }
  }

  @override
  Future<MerchantProfile> saveProfile({
    required String token,
    required String storeName,
  }) async {
    final body = await api.request(
      method: 'PUT',
      path: '/merchants/me',
      token: token,
      body: {'storeName': storeName},
    );
    return MerchantProfile.fromJson(body['merchant'] as Map<String, dynamic>);
  }

  @override
  Future<List<SurplusFood>> myFoods({required String token}) async {
    final body = await api.request(
      method: 'GET',
      path: '/merchants/me/foods',
      token: token,
      query: {'limit': '200'},
    );

    final foods = body['foods'];
    if (foods is! List) {
      throw const ApiException('Format daftar makanan tidak sesuai.');
    }
    return foods.whereType<Map<String, dynamic>>().map(SurplusFood.fromJson).toList();
  }

  @override
  Future<MerchantStats> stats({required String token}) async {
    final body = await api.request(
      method: 'GET',
      path: '/merchants/me/stats',
      token: token,
    );
    return MerchantStats.fromJson(body);
  }

  @override
  Future<SurplusFood> createFood({
    required String token,
    required String name,
    required String description,
    required int originalPrice,
    required int discountPrice,
    required int quota,
    required String pickupWindow,
  }) async {
    final body = await api.request(
      method: 'POST',
      path: '/foods',
      token: token,
      body: {
        'name': name,
        'description': description,
        'originalPrice': originalPrice,
        'discountPrice': discountPrice,
        'quota': quota,
        'pickupWindow': pickupWindow,
      },
    );
    return SurplusFood.fromJson(body['food'] as Map<String, dynamic>);
  }

  @override
  Future<SurplusFood> updateQuota({
    required String token,
    required int foodId,
    required int quota,
  }) async {
    final body = await api.request(
      method: 'PATCH',
      path: '/foods/$foodId',
      token: token,
      body: {'quota': quota},
    );
    return SurplusFood.fromJson(body['food'] as Map<String, dynamic>);
  }
}

import '../db/database.dart';

/// Bentuk JSON yang dikirim ke klien.
///
/// Semua mapper ada di satu tempat supaya kontrak API tidak tersebar di
/// beberapa route — dan supaya field yang tidak boleh keluar (hash password)
/// tidak bisa "tidak sengaja" ikut di salah satu endpoint.

Map<String, dynamic> userJson(User user) => {
      'id': user.id,
      'email': user.email,
      'name': user.name,
      'role': user.role.name,
      'createdAt': user.createdAt.toUtc().toIso8601String(),
    };

Map<String, dynamic> merchantJson(Merchant merchant) => {
      'id': merchant.id,
      'storeName': merchant.storeName,
      'ownerId': merchant.ownerId,
      'createdAt': merchant.createdAt.toUtc().toIso8601String(),
    };

/// Katalog publik. `quota` adalah sisa porsi nyata — bukan angka karangan.
Map<String, dynamic> foodJson(
  SurplusFood food, {
  required String merchantName,
}) =>
    {
      'id': food.id,
      'merchantId': food.merchantId,
      'merchantName': merchantName,
      'name': food.name,
      'description': food.description,
      'originalPrice': food.originalPrice,
      'discountPrice': food.discountPrice,
      'quota': food.quota,
      'pickupWindow': food.pickupWindow,
      'isActive': food.isActive,
      'createdAt': food.createdAt.toUtc().toIso8601String(),
    };

Map<String, dynamic> orderJson(
  Order order, {
  required String buyerName,
  required String foodName,
  required String merchantName,
}) =>
    {
      'id': order.id,
      'pickupCode': order.pickupCode,
      'buyerId': order.buyerId,
      'buyerName': buyerName,
      'foodId': order.foodId,
      'foodName': foodName,
      'merchantName': merchantName,
      'quantity': order.quantity,
      'totalPrice': order.totalPrice,
      'status': order.status.name,
      'createdAt': order.createdAt.toUtc().toIso8601String(),
    };

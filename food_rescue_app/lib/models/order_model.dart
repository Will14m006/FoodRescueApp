import '../core/network/api_exception.dart';

/// Status pesanan — harus sama dengan `OrderStatus` di backend.
enum OrderStatus { pending, completed, cancelled }

extension OrderStatusX on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'MENUNGGU';
      case OrderStatus.completed:
        return 'SELESAI';
      case OrderStatus.cancelled:
        return 'DIBATALKAN';
    }
  }

  String get jsonValue {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  static OrderStatus fromJsonValue(String? value) {
    switch (value) {
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  /// Warna badge sesuai aturan arsitektur:
  /// COMPLETED: hijau, PENDING: oranye, CANCELLED: merah.
  int get colorValue {
    switch (this) {
      case OrderStatus.pending:
        return 0xFFF5A524;
      case OrderStatus.completed:
        return 0xFF30A46C;
      case OrderStatus.cancelled:
        return 0xFFE5484D;
    }
  }
}

class Order {
  final int id;
  final String pickupCode;
  final int buyerId;
  final String buyerName;
  final int foodId;
  final String surplusFoodName;
  final String merchantName;
  final int quantity;
  final int totalPrice;
  final OrderStatus status;
  final DateTime createdAt;

  /// Bukti pengambilan (foto kamera) — **hanya lokal**, disimpan sebagai
  /// base64 di perangkat. Backend tidak menyimpan gambar; kode pick-up tetap
  /// satu-satunya bukti yang diverifikasi server.
  final String? proofPhoto;

  const Order({
    required this.id,
    required this.pickupCode,
    required this.buyerName,
    required this.surplusFoodName,
    required this.quantity,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.buyerId = 0,
    this.foodId = 0,
    this.merchantName = 'Mitra Food Rescue',
    this.proofPhoto,
  });

  Order copyWith({
    OrderStatus? status,
    String? proofPhoto,
    String? buyerName,
    String? surplusFoodName,
  }) {
    return Order(
      id: id,
      pickupCode: pickupCode,
      buyerId: buyerId,
      buyerName: buyerName ?? this.buyerName,
      foodId: foodId,
      surplusFoodName: surplusFoodName ?? this.surplusFoodName,
      merchantName: merchantName,
      quantity: quantity,
      totalPrice: totalPrice,
      status: status ?? this.status,
      createdAt: createdAt,
      proofPhoto: proofPhoto ?? this.proofPhoto,
    );
  }

  /// Dari `GET /orders` (dan `POST /orders`).
  factory Order.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final pickupCode = json['pickupCode'];
    final quantity = json['quantity'];
    final totalPrice = json['totalPrice'];
    final createdAt = json['createdAt'];

    if (id is! int) throw const ApiException('ID pesanan tidak valid.');
    if (pickupCode is! String || pickupCode.isEmpty) {
      throw const ApiException('Kode pick-up tidak diterima.');
    }
    if (quantity is! int || quantity < 1) {
      throw const ApiException('Jumlah pesanan tidak valid.');
    }
    if (totalPrice is! int || totalPrice < 0) {
      throw const ApiException('Total pesanan tidak valid.');
    }
    final created = createdAt is String ? DateTime.tryParse(createdAt) : null;
    if (created == null) {
      throw const ApiException('Waktu pesanan tidak valid.');
    }

    return Order(
      id: id,
      pickupCode: pickupCode,
      buyerId: json['buyerId'] as int? ?? 0,
      buyerName: (json['buyerName'] as String?)?.trim().isNotEmpty == true
          ? json['buyerName'] as String
          : 'Pembeli',
      foodId: json['foodId'] as int? ?? 0,
      surplusFoodName:
          (json['foodName'] as String?)?.trim().isNotEmpty == true
              ? json['foodName'] as String
              : 'Makanan surplus',
      merchantName:
          (json['merchantName'] as String?)?.trim().isNotEmpty == true
              ? json['merchantName'] as String
              : 'Mitra Food Rescue',
      quantity: quantity,
      totalPrice: totalPrice,
      status: OrderStatusX.fromJsonValue(json['status'] as String?),
      createdAt: created,
    );
  }

  /// Serialisasi untuk cache lokal di perangkat.
  Map<String, dynamic> toJson() => {
        'id': id,
        'pickupCode': pickupCode,
        'buyerId': buyerId,
        'buyerName': buyerName,
        'foodId': foodId,
        'surplusFoodName': surplusFoodName,
        'merchantName': merchantName,
        'quantity': quantity,
        'totalPrice': totalPrice,
        'status': status.jsonValue,
        'createdAt': createdAt.toIso8601String(),
        if (proofPhoto != null) 'proofPhoto': proofPhoto,
      };

  factory Order.fromCacheJson(Map<String, dynamic> json) =>
      Order.fromJson(json);

  @override
  bool operator ==(Object other) {
    return other is Order &&
        other.id == id &&
        other.pickupCode == pickupCode &&
        other.buyerId == buyerId &&
        other.buyerName == buyerName &&
        other.foodId == foodId &&
        other.surplusFoodName == surplusFoodName &&
        other.merchantName == merchantName &&
        other.quantity == quantity &&
        other.totalPrice == totalPrice &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.proofPhoto == proofPhoto;
  }

  @override
  int get hashCode => Object.hash(
        id,
        pickupCode,
        buyerId,
        buyerName,
        foodId,
        surplusFoodName,
        merchantName,
        quantity,
        totalPrice,
        status,
        createdAt,
        proofPhoto,
      );
}

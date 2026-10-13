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

  static OrderStatus fromJsonValue(String value) {
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
  final String id;
  final String pickupCode;
  final String buyerName;
  final String surplusFoodName;
  final int quantity;
  final int totalPrice;
  final OrderStatus status;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.pickupCode,
    required this.buyerName,
    required this.surplusFoodName,
    required this.quantity,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) {
    return other is Order &&
        other.id == id &&
        other.pickupCode == pickupCode &&
        other.buyerName == buyerName &&
        other.surplusFoodName == surplusFoodName &&
        other.quantity == quantity &&
        other.totalPrice == totalPrice &&
        other.status == status &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        pickupCode,
        buyerName,
        surplusFoodName,
        quantity,
        totalPrice,
        status,
        createdAt,
      );

  /// Serialisasi ke JSON supaya bisa disimpan di local storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pickupCode': pickupCode,
      'buyerName': buyerName,
      'surplusFoodName': surplusFoodName,
      'quantity': quantity,
      'totalPrice': totalPrice,
      'status': status.jsonValue,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Deserialisasi dari local storage.
  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      pickupCode: json['pickupCode'] as String,
      buyerName: json['buyerName'] as String,
      surplusFoodName: json['surplusFoodName'] as String,
      quantity: json['quantity'] as int,
      totalPrice: json['totalPrice'] as int,
      status: OrderStatusX.fromJsonValue(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

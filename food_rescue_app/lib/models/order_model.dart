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
}

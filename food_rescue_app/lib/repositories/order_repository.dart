import '../models/order_model.dart';

abstract class OrderRepository {
  Future<Order> createOrder({
    required String buyerName,
    required String surplusFoodId,
    required String surplusFoodName,
    required int quantity,
    required int unitPrice,
  });
}

/// Implementasi palsu (fake) yang mensimulasikan POST /api/orders ke backend.
///
/// Menghasilkan kode pick-up unik (contoh: RESCUE-101) sesuai arsitektur:
/// "Endpoint to create an order and generate a unique PickupCode".
class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository({this.delay = const Duration(milliseconds: 1500)});

  final Duration delay;
  int _counter = 100;

  @override
  Future<Order> createOrder({
    required String buyerName,
    required String surplusFoodId,
    required String surplusFoodName,
    required int quantity,
    required int unitPrice,
  }) async {
    await Future.delayed(delay);

    _counter += 1;

    return Order(
      id: 'ord-$_counter',
      pickupCode: 'RESCUE-$_counter',
      buyerName: buyerName,
      surplusFoodName: surplusFoodName,
      quantity: quantity,
      totalPrice: unitPrice * quantity,
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
    );
  }
}

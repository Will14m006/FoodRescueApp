import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order_model.dart';
import '../repositories/order_repository.dart';

/// Repository dibungkus provider supaya bisa di-inject & di-override saat test.
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return FakeOrderRepository();
});

/// Notifier untuk Fitur 2: Booking / Pemesanan makanan surplus.
///
/// State awal: null (belum ada pesanan). Saat [submit] dipanggil, state menjadi
/// loading (UI tombol jadi disabled & berputar) lalu berisi [Order] yang
/// berhasil dibuat beserta kode pick-up-nya.
class BookingNotifier extends AsyncNotifier<Order?> {
  @override
  Order? build() => null;

  Future<void> submit({
    required String buyerName,
    required String surplusFoodId,
    required String surplusFoodName,
    required int quantity,
    required int unitPrice,
  }) async {
    state = const AsyncLoading<Order?>();

    state = await AsyncValue.guard(() {
      return ref.read(orderRepositoryProvider).createOrder(
            buyerName: buyerName,
            surplusFoodId: surplusFoodId,
            surplusFoodName: surplusFoodName,
            quantity: quantity,
            unitPrice: unitPrice,
          );
    });
  }

  /// Dipanggil setelah kode pick-up selesai ditampilkan, agar form siap dipakai
  /// untuk pesanan berikutnya.
  void reset() {
    state = const AsyncData<Order?>(null);
  }
}

final bookingProvider = AsyncNotifierProvider<BookingNotifier, Order?>(BookingNotifier.new);

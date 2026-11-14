import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order_model.dart';
import '../repositories/order_repository.dart';
import 'auth_provider.dart';

/// P6: Pesanan sekarang disimpan ke backend sungguhan.
/// Override provider ini di widget test dengan [FakeOrderRepository].
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return ApiOrderRepository();
});

/// Notifier untuk Fitur 2: Booking / Pemesanan makanan surplus.
///
/// State awal: null (belum ada pesanan). Saat [submit] dipanggil, state menjadi
/// loading (UI tombol jadi disabled & berputar) lalu berisi [Order] yang
/// berhasil dibuat beserta kode pick-up-nya.
class BookingNotifier extends AsyncNotifier<Order?> {
  @override
  Order? build() => null;

  /// P10 fix #4: booking wajib punya user login, dan id user diteruskan ke
  /// repository (dulu hard-coded `userId: 1`).
  Future<void> submit({
    required String buyerName,
    required String surplusFoodId,
    required String surplusFoodName,
    required int quantity,
    required int unitPrice,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = AsyncError(
        const BookingException('Kamu harus login dulu untuk memesan.'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading<Order?>();

    state = await AsyncValue.guard(() {
      return ref.read(orderRepositoryProvider).createOrder(
            buyerName: buyerName,
            surplusFoodId: surplusFoodId,
            surplusFoodName: surplusFoodName,
            quantity: quantity,
            unitPrice: unitPrice,
            userId: user.id,
          );
    });
  }

  /// Dipanggil setelah kode pick-up selesai ditampilkan, agar form siap dipakai
  /// untuk pesanan berikutnya.
  void reset() {
    state = const AsyncData<Order?>(null);
  }
}

class BookingException implements Exception {
  const BookingException(this.message);
  final String message;

  @override
  String toString() => message;
}

final bookingProvider = AsyncNotifierProvider<BookingNotifier, Order?>(BookingNotifier.new);

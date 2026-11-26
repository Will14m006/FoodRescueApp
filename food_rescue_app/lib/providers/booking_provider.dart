import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../models/order_model.dart';
import 'auth_provider.dart';
import 'orders_provider.dart';

/// Pemesanan makanan surplus.
///
/// State awal null. Saat [submit] dipanggil, state menjadi loading (tombol
/// non-aktif) lalu berisi [Order] dari server beserta kode pick-up-nya.
class BookingNotifier extends AsyncNotifier<Order?> {
  @override
  Order? build() => null;

  Future<void> submit({
    required String surplusFoodId,
    required int quantity,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = AsyncError(
        const ApiException('Kamu harus login dulu untuk memesan.'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading<Order?>();

    state = await AsyncValue.guard(() {
      return ref.read(orderRepositoryProvider).createOrder(
            token: user.token,
            foodId: int.parse(surplusFoodId),
            quantity: quantity,
          );
    });
  }

  /// Setelah kode pick-up ditampilkan, form siap dipakai lagi.
  void reset() {
    state = const AsyncData<Order?>(null);
  }
}

final bookingProvider =
    AsyncNotifierProvider<BookingNotifier, Order?>(BookingNotifier.new);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order_model.dart';
import '../repositories/order_repository.dart';
import '../repositories/proof_photo_store.dart';
import 'auth_provider.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return ApiOrderRepository(api: ref.watch(apiClientProvider));
});

/// Foto bukti dipisah per akun, sama seperti sesi.
final proofPhotoStoreProvider = Provider<ProofPhotoStore>((ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  return ProofPhotoStore(userId: userId);
});

/// Daftar pesanan: **server** adalah sumber data, foto bukti tetap lokal.
///
/// Pemisahan ini disengaja. Status pesanan harus sama di semua perangkat
/// (merchant memverifikasi kode pickup), sedangkan foto bukti hanya relevan
/// untuk pembeli yang mengambilnya.
class OrdersNotifier extends AsyncNotifier<List<Order>> {
  @override
  Future<List<Order>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return [];

    final orders =
        await ref.read(orderRepositoryProvider).fetchOrders(token: user.token);
    final proofs = await ref.read(proofPhotoStoreProvider).loadAll();

    return [
      for (final order in orders)
        if (proofs['${order.id}'] case final photo?)
          order.copyWith(proofPhoto: photo)
        else
          order,
    ];
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  /// Simpan bukti foto lalu tampilkan tanpa menunggu server.
  Future<void> attachProof(int orderId, String base64Photo) async {
    await ref.read(proofPhotoStoreProvider).save(orderId, base64Photo);

    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final order in current)
        order.id == orderId ? order.copyWith(proofPhoto: base64Photo) : order,
    ]);
  }

  /// Merchant/admin menyelesaikan pesanan dengan kode pick-up dari pembeli.
  Future<void> complete({
    required int orderId,
    required String pickupCode,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final updated = await ref.read(orderRepositoryProvider).complete(
          token: user.token,
          orderId: orderId,
          pickupCode: pickupCode,
        );

    final current = state.valueOrNull ?? const <Order>[];
    final proofs = await ref.read(proofPhotoStoreProvider).loadAll();
    final photo = proofs['${updated.id}'];

    state = AsyncData([
      for (final order in current)
        order.id == updated.id
            ? updated.copyWith(proofPhoto: photo)
            : order,
    ]);
  }

  Future<void> cancel(int orderId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final updated = await ref
        .read(orderRepositoryProvider)
        .cancel(token: user.token, orderId: orderId);

    final current = state.valueOrNull ?? const <Order>[];
    final proofs = await ref.read(proofPhotoStoreProvider).loadAll();
    final photo = proofs['${updated.id}'];

    state = AsyncData([
      for (final order in current)
        order.id == updated.id
            ? updated.copyWith(proofPhoto: photo)
            : order,
    ]);
  }
}

final ordersProvider =
    AsyncNotifierProvider<OrdersNotifier, List<Order>>(OrdersNotifier.new);

/// Pesanan yang masih bisa diubah (pending).
final activeOrdersProvider = Provider<List<Order>>((ref) {
  final orders = ref.watch(ordersProvider).valueOrNull ?? const <Order>[];
  return orders.where((o) => o.status == OrderStatus.pending).toList();
});

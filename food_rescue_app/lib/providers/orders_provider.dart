import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order_model.dart';
import '../repositories/order_local_repository.dart';
import 'auth_provider.dart';

/// Repository lokal dibungkus provider supaya bisa di-inject & di-override saat test.
///
/// P10 fix #1: repository kini tahu [userId] aktif, jadi storage dipisah per
/// akun. Provider ini ikut rebuild saat user berganti (login/logout).
final orderLocalRepositoryProvider = Provider<OrderLocalRepository>((ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  return OrderLocalRepositoryImpl(userId: userId);
});

/// Daftar SharedPreferences yang di-override saat test (simulasi storage).
final prefsOverrideProvider = Provider<List<SharedPreferencesAsync>>((ref) {
  return [];
});

/// Notifier untuk P5: Local Data & Persistence (Riwayat Pesanan).
///
/// Memuat daftar pesanan dari local storage saat aplikasi dibuka, lalu
/// menyediakan operasi Create / Read / Update / Delete yang langsung
/// ditulis kembali ke storage. Karena data ada di storage (bukan memory),
/// pesanan tetap ada setelah aplikasi ditutup & dibuka lagi.
///
/// P10 fix #1: `build` juga `watch` user aktif, sehingga logout/login
/// otomatis memuat ulang riwayat milik akun yang baru.
class OrdersNotifier extends AsyncNotifier<List<Order>> {
  @override
  Future<List<Order>> build() async {
    ref.watch(currentUserProvider);
    return _repository().loadOrders();
  }

  OrderLocalRepository _repository() {
    return ref.read(orderLocalRepositoryProvider);
  }

  // === CREATE ===
  Future<void> addOrder(Order order) async {
    await _repository().saveOrder(order);
    state = AsyncData(await _repository().loadOrders());
  }

  // === UPDATE ===
  Future<void> markCompleted(String orderId, {String? proofPhoto}) async {
    await _repository().updateOrderStatus(
      orderId,
      OrderStatus.completed,
      proofPhoto: proofPhoto,
    );
    state = AsyncData(await _repository().loadOrders());
  }

  Future<void> markCancelled(String orderId) async {
    await _repository().updateOrderStatus(orderId, OrderStatus.cancelled);
    state = AsyncData(await _repository().loadOrders());
  }

  // Catatan: tidak ada operasi DELETE untuk user. Pesanan bersifat permanen
  // supaya riwayat tidak bisa dimanipulasi. Method deleteOrder tetap ada di
  // repository hanya untuk keperluan test kebersihan storage.

  // === UTIL ===
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _repository().loadOrders());
  }
}

final ordersProvider =
    AsyncNotifierProvider<OrdersNotifier, List<Order>>(OrdersNotifier.new);

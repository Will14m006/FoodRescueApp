import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order_model.dart';
import '../models/surplus_food_model.dart';
import '../models/user_role.dart';
import '../repositories/admin_repository.dart';
import 'auth_provider.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return ApiAdminRepository(api: ref.watch(apiClientProvider));
});

final adminStatsProvider = FutureProvider<AdminStats>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.role != UserRole.admin) {
    throw StateError('Hanya admin yang bisa melihat statistik.');
  }
  return ref.read(adminRepositoryProvider).stats(token: user.token);
});

/// Filter peran di daftar user admin.
final adminUserFilterProvider = StateProvider<UserRole?>((ref) => null);

/// Kata kunci pencarian user (email atau nama).
final adminUserSearchProvider = StateProvider<String>((ref) => '');

final adminUsersProvider = FutureProvider<List<AdminUser>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.role != UserRole.admin) {
    throw StateError('Hanya admin yang bisa melihat daftar user.');
  }

  return ref.read(adminRepositoryProvider).users(
        token: user.token,
        role: ref.watch(adminUserFilterProvider),
        query: ref.watch(adminUserSearchProvider),
      );
});

/// Semua makanan lintas toko.
final adminFoodsProvider = FutureProvider<List<SurplusFood>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.role != UserRole.admin) {
    throw StateError('Hanya admin yang bisa melihat semua makanan.');
  }
  return ref.read(adminRepositoryProvider).foods(token: user.token);
});

/// Filter status di daftar pesanan admin.
final adminOrderFilterProvider = StateProvider<OrderStatus?>((ref) => null);

/// Semua pesanan lintas toko.
final adminOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.role != UserRole.admin) {
    throw StateError('Hanya admin yang bisa melihat semua pesanan.');
  }
  return ref.read(adminRepositoryProvider).orders(
        token: user.token,
        status: ref.watch(adminOrderFilterProvider),
      );
});

/// Tangguhkan / aktifkan akun lalu segarkan daftar.
Future<void> setUserActive(
  WidgetRef ref, {
  required int userId,
  required bool isActive,
}) async {
  final user = ref.read(currentUserProvider);
  if (user == null || user.role != UserRole.admin) {
    throw StateError('Hanya admin yang bisa mengubah akun.');
  }

  await ref.read(adminRepositoryProvider).setUserActive(
        token: user.token,
        userId: userId,
        isActive: isActive,
      );
  ref.invalidate(adminUsersProvider);
  ref.invalidate(adminStatsProvider);
}

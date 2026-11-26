import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final adminUsersProvider = FutureProvider<List<AdminUser>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.role != UserRole.admin) {
    throw StateError('Hanya admin yang bisa melihat daftar user.');
  }

  return ref.read(adminRepositoryProvider).users(
        token: user.token,
        role: ref.watch(adminUserFilterProvider),
      );
});

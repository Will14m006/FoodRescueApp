import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/surplus_food_model.dart';
import '../repositories/merchant_repository.dart';
import 'auth_provider.dart';
import 'catalog_provider.dart';

final merchantRepositoryProvider = Provider<MerchantRepository>((ref) {
  return ApiMerchantRepository(api: ref.watch(apiClientProvider));
});

/// Profil toko merchant yang sedang login. `null` = belum membuat toko.
class MerchantProfileNotifier extends AsyncNotifier<MerchantProfile?> {
  @override
  Future<MerchantProfile?> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return null;
    return ref.read(merchantRepositoryProvider).profile(token: user.token);
  }

  Future<void> saveProfile(String storeName) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(merchantRepositoryProvider).saveProfile(
            token: user.token,
            storeName: storeName,
          ),
    );
  }
}

final merchantProfileProvider =
    AsyncNotifierProvider<MerchantProfileNotifier, MerchantProfile?>(
  MerchantProfileNotifier.new,
);

/// Semua makanan milik toko sendiri (termasuk nonaktif & kuota 0).
class MerchantFoodsNotifier extends AsyncNotifier<List<SurplusFood>> {
  @override
  Future<List<SurplusFood>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return [];
    return ref.read(merchantRepositoryProvider).myFoods(token: user.token);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> updateQuota(int foodId, int quota) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final updated = await ref.read(merchantRepositoryProvider).updateQuota(
          token: user.token,
          foodId: foodId,
          quota: quota,
        );

    _replace(updated);
    ref.invalidate(merchantStatsProvider);
  }

  /// Ubah detail lengkap makanan. Dipakai form edit.
  Future<void> updateFood({
    required int foodId,
    String? name,
    String? description,
    int? originalPrice,
    int? discountPrice,
    int? quota,
    String? pickupWindow,
    bool? isActive,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final updated = await ref.read(merchantRepositoryProvider).updateFood(
          token: user.token,
          foodId: foodId,
          name: name,
          description: description,
          originalPrice: originalPrice,
          discountPrice: discountPrice,
          quota: quota,
          pickupWindow: pickupWindow,
          isActive: isActive,
        );

    _replace(updated);
    ref.invalidate(merchantStatsProvider);
    ref.invalidate(catalogProvider);
  }

  /// Soft delete: makanan hilang dari katalog, pesanan lama tetap utuh.
  Future<void> deactivate(int foodId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final updated = await ref.read(merchantRepositoryProvider).deactivateFood(
          token: user.token,
          foodId: foodId,
        );

    _replace(updated);
    ref.invalidate(merchantStatsProvider);
    ref.invalidate(catalogProvider);
  }

  void _replace(SurplusFood updated) {
    final current = state.valueOrNull ?? const <SurplusFood>[];
    state = AsyncData([
      for (final food in current) food.id == updated.id ? updated : food,
    ]);
  }

  Future<void> create({
    required String name,
    required String description,
    required int originalPrice,
    required int discountPrice,
    required int quota,
    required String pickupWindow,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final created = await ref.read(merchantRepositoryProvider).createFood(
          token: user.token,
          name: name,
          description: description,
          originalPrice: originalPrice,
          discountPrice: discountPrice,
          quota: quota,
          pickupWindow: pickupWindow,
        );

    final current = state.valueOrNull ?? const <SurplusFood>[];
    state = AsyncData([created, ...current]);
    ref.invalidate(merchantStatsProvider);
    ref.invalidate(catalogProvider);
  }
}

final merchantFoodsProvider =
    AsyncNotifierProvider<MerchantFoodsNotifier, List<SurplusFood>>(
  MerchantFoodsNotifier.new,
);

final merchantStatsProvider = FutureProvider<MerchantStats>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw StateError('Belum login.');
  }
  return ref.read(merchantRepositoryProvider).stats(token: user.token);
});

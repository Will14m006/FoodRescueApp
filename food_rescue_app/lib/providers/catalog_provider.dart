import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/surplus_food_model.dart';
import '../repositories/surplus_food_repository.dart';
import 'auth_provider.dart';

/// Katalog dari `GET /foods`. Override di widget test dengan fake.
final surplusFoodRepositoryProvider = Provider<SurplusFoodRepository>((ref) {
  return ApiSurplusFoodRepository(api: ref.watch(apiClientProvider));
});

/// Query pencarian katalog (dipakai untuk mendemokan "empty state").
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Kategori yang sedang dipilih di chip filter.
final selectedCategoryProvider =
    StateProvider<FoodCategory>((ref) => FoodCategory.all);

/// Notifier untuk Fitur 1: Katalog Surplus (Buyer Feed).
class CatalogNotifier extends AsyncNotifier<List<SurplusFood>> {
  @override
  Future<List<SurplusFood>> build() {
    return _fetch();
  }

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Kurangi kuota item setelah pesanan berhasil, supaya angka "sisa porsi"
  /// tidak beku. Server tetap sumber kebenaran; ini hanya optimasi tampilan.
  void reduceQuota(int foodId, int quantity) {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncData([
      for (final food in current)
        food.id == foodId ? food.copyWithQuota(food.quota - quantity) : food,
    ]);
  }

  Future<List<SurplusFood>> _fetch() {
    return ref.read(surplusFoodRepositoryProvider).fetchSurplusFoods();
  }
}

final catalogProvider =
    AsyncNotifierProvider<CatalogNotifier, List<SurplusFood>>(
  CatalogNotifier.new,
);

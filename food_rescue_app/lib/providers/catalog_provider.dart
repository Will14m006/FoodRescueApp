import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/surplus_food_model.dart';
import '../repositories/surplus_food_repository.dart';

/// Repository dibungkus provider supaya bisa di-inject & di-override saat test.
final surplusFoodRepositoryProvider = Provider<SurplusFoodRepository>((ref) {
  return FakeSurplusFoodRepository();
});

/// Query pencarian katalog (dipakai untuk mendemokan "empty state").
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Notifier untuk Fitur 1: Katalog Surplus (Buyer Feed).
///
/// Memakai AsyncNotifier sehingga state loading / data / error terurus seragam.
class CatalogNotifier extends AsyncNotifier<List<SurplusFood>> {
  @override
  Future<List<SurplusFood>> build() async {
    return _fetch();
  }

  Future<void> retry() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<List<SurplusFood>> _fetch() {
    return ref.read(surplusFoodRepositoryProvider).fetchSurplusFoods();
  }
}

final catalogProvider =
    AsyncNotifierProvider<CatalogNotifier, List<SurplusFood>>(CatalogNotifier.new);

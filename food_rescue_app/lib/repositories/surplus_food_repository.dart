import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/surplus_food_model.dart';

abstract class SurplusFoodRepository {
  Future<List<SurplusFood>> fetchSurplusFoods();
}

/// Katalog publik: `GET /foods` (hanya yang aktif & masih ada kuota).
class ApiSurplusFoodRepository implements SurplusFoodRepository {
  ApiSurplusFoodRepository({required this.api});

  final ApiClient api;

  @override
  Future<List<SurplusFood>> fetchSurplusFoods() async {
    final body = await api.request(method: 'GET', path: '/foods');

    final foods = body['foods'];
    if (foods is! List) {
      throw const ApiException('Format katalog dari server tidak sesuai.');
    }

    return foods
        .whereType<Map<String, dynamic>>()
        .map(SurplusFood.fromJson)
        .where((food) => food.isAvailable)
        .toList();
  }
}

/// Implementasi palsu yang mensimulasikan panggilan API ke backend.
///
/// Dipakai widget test supaya test tidak bergantung jaringan. Delay 1.2 detik
/// sengaja dibuat agar state "loading" benar-benar terlihat.
/// Flag [simulateFailureOnFirstCall] dibuat agar state "error + retry" bisa
/// didemokan: pemanggilan pertama gagal, lalu sukses ketika tombol Retry
/// ditekan (persis seperti jaringan tidak stabil di dunia nyata).
class FakeSurplusFoodRepository implements SurplusFoodRepository {
  FakeSurplusFoodRepository({
    this.simulateFailureOnFirstCall = true,
    this.returnEmpty = false,
    this.delay = const Duration(milliseconds: 1200),
  });

  final bool simulateFailureOnFirstCall;
  final bool returnEmpty;
  final Duration delay;

  bool _hasFailedOnce = false;

  static const _seedFoods = <SurplusFood>[
    SurplusFood(
      id: 1,
      merchantName: 'Roti O Bakso',
      name: 'Paket Roti Sisa Hari Ini',
      description: 'Isi 6 pcs roti varian klasik, masih segar dari oven pagi.',
      originalPrice: 40000,
      discountPrice: 15000,
      quota: 4,
      pickupWindow: '19:00 - 21:00',
      category: FoodCategory.bakery,
      emoji: '🥖',
    ),
    SurplusFood(
      id: 2,
      merchantName: 'Kafe Senja',
      name: 'Pastry & Croissant',
      description: 'Croissant butter & pain au chocolat, 4 pcs campuran.',
      originalPrice: 65000,
      discountPrice: 20000,
      quota: 2,
      pickupWindow: '20:00 - 22:00',
      category: FoodCategory.snack,
      emoji: '🥐',
    ),
    SurplusFood(
      id: 3,
      merchantName: 'Warung Nasi Ibu Ani',
      name: 'Nasi Sayur + Lauk Ayam',
      description: 'Nasi putih, sayur asem, ayam goreng, dan sambal rumahan.',
      originalPrice: 25000,
      discountPrice: 10000,
      quota: 5,
      pickupWindow: '21:00 - 22:30',
      category: FoodCategory.main,
      emoji: '🍱',
    ),
    SurplusFood(
      id: 4,
      merchantName: 'Bakery Sumber Rezeki',
      name: 'Roti Tawar & Donat (5 pcs)',
      description: 'Roti tawar gandum 3 pcs + donat gula 2 pcs.',
      originalPrice: 30000,
      discountPrice: 12000,
      quota: 3,
      pickupWindow: '18:30 - 20:00',
      category: FoodCategory.bakery,
      emoji: '🍩',
    ),
    SurplusFood(
      id: 5,
      merchantName: 'Mie Ayam Pak Dwi',
      name: 'Mie Ayam Special + Es Teh',
      description: 'Mie ayam jamur, pangsit goreng, dan segelas es teh manis.',
      originalPrice: 20000,
      discountPrice: 9000,
      quota: 6,
      pickupWindow: '21:30 - 23:00',
      category: FoodCategory.main,
      emoji: '🍜',
    ),
    SurplusFood(
      id: 6,
      merchantName: 'Segar Juice Bar',
      name: 'Jus Alpukat Murni (500ml)',
      description: 'Alpukat lokal tanpa gula tambahan, langsung diperas.',
      originalPrice: 28000,
      discountPrice: 10000,
      quota: 3,
      pickupWindow: '20:30 - 22:00',
      category: FoodCategory.drink,
      emoji: '🥤',
    ),
  ];

  @override
  Future<List<SurplusFood>> fetchSurplusFoods() async {
    await Future.delayed(delay);

    if (simulateFailureOnFirstCall && !_hasFailedOnce) {
      _hasFailedOnce = true;
      throw const ApiException(
        'Gagal memuat katalog makanan. Periksa koneksi internet kamu.',
      );
    }

    if (returnEmpty) return [];

    return _seedFoods.where((food) => food.isAvailable).toList();
  }
}

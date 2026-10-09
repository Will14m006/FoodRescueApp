// Widget test untuk Fitur 1: Katalog Surplus (Buyer Feed).
//
// Menguji 4 state utama: initial loading, data berhasil dimuat,
// empty state, dan error state dengan tombol retry.
// Repository di-override dengan versi cepat & terkontrol supaya test
// deterministik (tidak tergantung delay 1.2 detik versi production).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_rescue_app/main.dart';
import 'package:food_rescue_app/models/surplus_food_model.dart';
import 'package:food_rescue_app/providers/catalog_provider.dart';
import 'package:food_rescue_app/repositories/surplus_food_repository.dart';
import 'package:food_rescue_app/widgets/food_card_skeleton.dart';

const _testFoods = <SurplusFood>[
  SurplusFood(
    id: 't-1',
    merchantName: 'Roti O Bakso',
    name: 'Paket Roti Sisa Hari Ini',
    description: 'Isi 6 pcs roti.',
    originalPrice: 40000,
    discountPrice: 15000,
    quota: 4,
    pickupWindow: '19:00 - 21:00',
    category: FoodCategory.bakery,
  ),
  SurplusFood(
    id: 't-2',
    merchantName: 'Kafe Senja',
    name: 'Pastry & Croissant',
    description: 'Croissant & pain au chocolat.',
    originalPrice: 65000,
    discountPrice: 20000,
    quota: 2,
    pickupWindow: '20:00 - 22:00',
    category: FoodCategory.snack,
  ),
];

/// Viewport diperbesar (800x1400) supaya seluruh isi layar login & katalog
/// masuk ke area hit-test, termasuk tombol "Masuk" yang ada di bawah.
Future<void> _pumpApp(WidgetTester tester, List<Override> overrides) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: FoodRescueApp(),
      ),
    ),
  );
}

/// Tombol "Masuk" di layar login.
Finder get _loginButton =>
    find.descendant(of: find.byType(ElevatedButton), matching: find.text('Masuk'));

void main() {
  testWidgets('state loading: menampilkan skeleton shimmer saat data belum ada',
      (WidgetTester tester) async {
    await _pumpApp(tester, [
      surplusFoodRepositoryProvider.overrideWithValue(_SlowRepo()),
    ]);

    // Login screen dulu; langsung ke dashboard.
    await tester.tap(_loginButton);
    await tester.pump(); // frame navigasi ke dashboard
    await tester.pump(const Duration(milliseconds: 100)); // masih loading (delay 30 detik)

    // Skeleton shimmer harus terlihat karena data belum selesai dimuat.
    expect(find.byType(FoodCardSkeleton), findsWidgets);

    // Bersihkan timer tersisa supaya test bisa selesai dengan rapi.
    await tester.pumpAndSettle();
  });

  testWidgets('state data berhasil dimuat: daftar makanan tampil',
      (WidgetTester tester) async {
    await _pumpApp(tester, [
      surplusFoodRepositoryProvider.overrideWithValue(
        FakeSurplusFoodRepository(
          simulateFailureOnFirstCall: false,
          delay: const Duration(milliseconds: 10),
        ),
      ),
    ]);

    await tester.tap(_loginButton);
    await tester.pumpAndSettle();

    // Header katalog & salah satu nama toko pasti tampil.
    expect(find.text('Katalog surplus hari ini'), findsOneWidget);
    expect(find.text('Kafe Senja'), findsWidgets);
    expect(find.byType(FoodCardSkeleton), findsNothing);
  });

  testWidgets('state empty: pencarian tanpa hasil memunculkan empty state',
      (WidgetTester tester) async {
    await _pumpApp(tester, [
      surplusFoodRepositoryProvider.overrideWithValue(
        FakeSurplusFoodRepository(
          simulateFailureOnFirstCall: false,
          delay: const Duration(milliseconds: 10),
        ),
      ),
    ]);

    await tester.tap(_loginButton);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'sate');
    await tester.pumpAndSettle();

    expect(find.text('Pencarian Tidak Ditemukan'), findsOneWidget);
    expect(find.text('Reset Filter'), findsOneWidget);
  });

  testWidgets('state empty: kuota habis total memunculkan empty state khusus',
      (WidgetTester tester) async {
    await _pumpApp(tester, [
      surplusFoodRepositoryProvider.overrideWithValue(
        FakeSurplusFoodRepository(
          simulateFailureOnFirstCall: false,
          returnEmpty: true,
          delay: const Duration(milliseconds: 10),
        ),
      ),
    ]);

    await tester.tap(_loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Belum Ada Makanan Tersedia'), findsOneWidget);
  });

  testWidgets('state error + retry: gagal memuat lalu sukses setelah retry',
      (WidgetTester tester) async {
    final repo = FakeSurplusFoodRepository(
      simulateFailureOnFirstCall: true,
      delay: const Duration(milliseconds: 10),
    );

    await _pumpApp(tester, [surplusFoodRepositoryProvider.overrideWithValue(repo)]);

    await tester.tap(_loginButton);
    await tester.pumpAndSettle();

    // Karena panggilan pertama gagal, error state harus muncul.
    expect(find.text('Yah, ada yang salah'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);

    // Tekan retry -> panggilan kedua sukses -> daftar muncul.
    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();

    expect(find.text('Yah, ada yang salah'), findsNothing);
    expect(find.text('Kafe Senja'), findsWidgets);
  });
}

/// Repository dengan delay yang sangat lama, dipakai untuk "membekukan" test
/// di tengah state loading.
class _SlowRepo implements SurplusFoodRepository {
  @override
  Future<List<SurplusFood>> fetchSurplusFoods() async {
    await Future.delayed(const Duration(seconds: 30));
    return _testFoods;
  }
}

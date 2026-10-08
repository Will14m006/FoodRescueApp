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

const _testFoods = <SurplusFood>[
  SurplusFood(
    id: 't-1',
    merchantName: 'Roti O Bakso',
    name: 'Paket Roti Sisa Hari Ini',
    originalPrice: 40000,
    discountPrice: 15000,
    quota: 4,
    pickupWindow: '19:00 - 21:00',
  ),
  SurplusFood(
    id: 't-2',
    merchantName: 'Kafe Senja',
    name: 'Pastry & Croissant',
    originalPrice: 65000,
    discountPrice: 20000,
    quota: 2,
    pickupWindow: '20:00 - 22:00',
  ),
];

Widget _wrapApp(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: child,
    ),
  );
}

void main() {
  testWidgets('state loading: menampilkan CircularProgressIndicator saat data belum ada',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrapApp(
        const FoodRescueApp(),
        [
          surplusFoodRepositoryProvider.overrideWithValue(
            _SlowRepo(),
          ),
        ],
      ),
    );

    // Login screen dulu; langsung ke dashboard.
    await tester.tap(find.text('Masuk'));
    await tester.pump(); // frame navigasi ke dashboard
    await tester.pump(const Duration(milliseconds: 100)); // masih loading (delay 30 detik)

    // Indikator harus terlihat karena data belum selesai dimuat.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Bersihkan timer tersisa supaya test bisa selesai dengan rapi.
    await tester.pumpAndSettle();
  });

  testWidgets('state data berhasil dimuat: daftar makanan tampil',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrapApp(
        const FoodRescueApp(),
        [
          surplusFoodRepositoryProvider.overrideWithValue(
            FakeSurplusFoodRepository(
              simulateFailureOnFirstCall: false,
              delay: const Duration(milliseconds: 10),
            ),
          ),
        ],
      ),
    );

    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Paket Roti Sisa Hari Ini'), findsOneWidget);
    expect(find.text('Kafe Senja'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('state empty: pencarian tanpa hasil memunculkan empty state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrapApp(
        const FoodRescueApp(),
        [
          surplusFoodRepositoryProvider.overrideWithValue(
            FakeSurplusFoodRepository(
              simulateFailureOnFirstCall: false,
              delay: const Duration(milliseconds: 10),
            ),
          ),
        ],
      ),
    );

    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'sate');
    await tester.pumpAndSettle();

    expect(find.text('Pencarian Tidak Ditemukan'), findsOneWidget);
    expect(find.text('Hapus Filter'), findsOneWidget);
  });

  testWidgets('state empty: kuota habis total memunculkan empty state khusus',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrapApp(
        const FoodRescueApp(),
        [
          surplusFoodRepositoryProvider.overrideWithValue(
            FakeSurplusFoodRepository(
              simulateFailureOnFirstCall: false,
              returnEmpty: true,
              delay: const Duration(milliseconds: 10),
            ),
          ),
        ],
      ),
    );

    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Belum Ada Makanan Tersedia'), findsOneWidget);
  });

  testWidgets('state error + retry: gagal memuat lalu sukses setelah retry',
      (WidgetTester tester) async {
    final repo = FakeSurplusFoodRepository(
      simulateFailureOnFirstCall: true,
      delay: const Duration(milliseconds: 10),
    );

    await tester.pumpWidget(
      _wrapApp(
        const FoodRescueApp(),
        [surplusFoodRepositoryProvider.overrideWithValue(repo)],
      ),
    );

    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    // Karena panggilan pertama gagal, error state harus muncul.
    expect(find.text('Terjadi Kesalahan'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);

    // Tekan retry -> panggilan kedua sukses -> daftar muncul.
    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();

    expect(find.text('Terjadi Kesalahan'), findsNothing);
    expect(find.text('Paket Roti Sisa Hari Ini'), findsOneWidget);
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

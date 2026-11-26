// Widget test untuk Fitur 1: Katalog Surplus (Buyer Feed).
//
// Menguji 4 state utama: initial loading, data berhasil dimuat,
// empty state, dan error state dengan tombol retry.
// Repository katalog di-override dengan fake cepat; sesi diisi di memori
// sehingga aplikasi langsung masuk dashboard pembeli tanpa jaringan.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_rescue_app/main.dart';
import 'package:food_rescue_app/models/surplus_food_model.dart';
import 'package:food_rescue_app/providers/catalog_provider.dart';
import 'package:food_rescue_app/repositories/surplus_food_repository.dart';
import 'package:food_rescue_app/widgets/food_card_skeleton.dart';

import 'support/fakes.dart';

const _testFoods = <SurplusFood>[
  SurplusFood(
    id: 1,
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
    id: 2,
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

Future<void> _pumpApp(
  WidgetTester tester,
  List<Override> extra, {
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final overrides = await sessionOverrides();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [...overrides, ...extra],
      child: const FoodRescueApp(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // Sesi masih dipulihkan di frame pertama; beri satu giliran supaya
    // dashboard benar-benar dibangun sebelum state loading dipotret.
    await tester.pump();
    await tester.pump();
  }
}

void main() {
  testWidgets('state loading: skeleton tampil saat data belum selesai',
      (WidgetTester tester) async {
    final slow = _SlowRepo();
    await _pumpApp(
      tester,
      [surplusFoodRepositoryProvider.overrideWithValue(slow)],
      settle: false,
    );

    expect(find.byType(FoodCardSkeleton), findsWidgets);

    // Selesaikan permintaan supaya tidak ada timer yang menggantung.
    slow.complete();
    await tester.pumpAndSettle();
    expect(find.byType(FoodCardSkeleton), findsNothing);
  });

  testWidgets('state data: daftar makanan tampil', (WidgetTester tester) async {
    await _pumpApp(tester, [
      surplusFoodRepositoryProvider.overrideWithValue(
        FakeSurplusFoodRepository(
          simulateFailureOnFirstCall: false,
          delay: const Duration(milliseconds: 10),
        ),
      ),
    ]);

    expect(find.textContaining('katalog surplus hari ini'), findsOneWidget);
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

    await tester.enterText(find.byType(TextField).first, 'sate');
    await tester.pumpAndSettle();

    expect(find.text('Pencarian Tidak Ditemukan'), findsOneWidget);
    expect(find.text('Reset Filter'), findsOneWidget);
  });

  testWidgets('state empty: katalog kosong memunculkan empty state khusus',
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

    expect(find.text('Belum Ada Makanan Tersedia'), findsOneWidget);
  });

  testWidgets('state error + retry: gagal memuat lalu sukses setelah retry',
      (WidgetTester tester) async {
    await _pumpApp(tester, [
      surplusFoodRepositoryProvider.overrideWithValue(
        FakeSurplusFoodRepository(
          simulateFailureOnFirstCall: true,
          delay: const Duration(milliseconds: 10),
        ),
      ),
    ]);

    expect(find.text('Yah, ada yang salah'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);

    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();

    expect(find.text('Yah, ada yang salah'), findsNothing);
    expect(find.text('Kafe Senja'), findsWidgets);
  });
}

/// Repository yang menahan hasil sampai [complete] dipanggil, dipakai untuk
/// memotret state loading tanpa meninggalkan timer yang menggantung.
class _SlowRepo implements SurplusFoodRepository {
  final _completer = Completer<List<SurplusFood>>();

  @override
  Future<List<SurplusFood>> fetchSurplusFoods() => _completer.future;

  void complete() => _completer.complete(_testFoods);
}

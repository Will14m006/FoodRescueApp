// Smoke test: aplikasi ter-build dan layar login tampil tanpa sesi.
//
// Sesi sengaja dikosongkan supaya alur "belum login" yang diuji.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_rescue_app/main.dart';
import 'package:food_rescue_app/providers/catalog_provider.dart';
import 'package:food_rescue_app/repositories/surplus_food_repository.dart';

import 'support/fakes.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...await sessionOverrides(user: null),
        surplusFoodRepositoryProvider.overrideWithValue(
          FakeSurplusFoodRepository(
            simulateFailureOnFirstCall: false,
            delay: Duration.zero,
          ),
        ),
      ],
      child: const FoodRescueApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tanpa sesi: diarahkan ke halaman masuk',
      (WidgetTester tester) async {
    await _pumpApp(tester);

    expect(find.text('Food Rescue'), findsOneWidget);
    expect(find.text('Masuk'), findsWidgets);
    // Dashboard pembeli tidak boleh tampil.
    expect(find.textContaining('katalog surplus hari ini'), findsNothing);
  });

  testWidgets('form login punya field email & password + tombol daftar',
      (WidgetTester tester) async {
    await _pumpApp(tester);

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.bySemanticsLabel('Email'), findsWidgets);
    expect(find.bySemanticsLabel('Password'), findsWidgets);
    expect(find.text('Belum punya akun? Daftar'), findsOneWidget);
  });

  testWidgets('mode daftar: muncul field nama dan pilihan peran',
      (WidgetTester tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Belum punya akun? Daftar'));
    await tester.pumpAndSettle();

    expect(find.text('Daftar Akun'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.widgetWithText(ChoiceChip, 'Pembeli'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Merchant'), findsOneWidget);
    // Admin tidak bisa didaftarkan sendiri dari aplikasi.
    expect(find.widgetWithText(ChoiceChip, 'Admin'), findsNothing);
  });

  testWidgets('alamat server tampil supaya jelas backend mana yang dituju',
      (WidgetTester tester) async {
    await _pumpApp(tester);

    expect(find.textContaining('Server: http'), findsOneWidget);
  });
}

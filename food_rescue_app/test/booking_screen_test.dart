// Widget test untuk Fitur 2: Booking / Pemesanan.
//
// Menguji: validasi input (nama & jumlah), tombol non-aktif saat loading
// (anti double-tap), dan state sukses yang menampilkan kode pick-up.
// OrderRepository di-override dengan versi cepat & terkontrol.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_rescue_app/models/surplus_food_model.dart';
import 'package:food_rescue_app/providers/booking_provider.dart';
import 'package:food_rescue_app/repositories/order_repository.dart';
import 'package:food_rescue_app/screens/booking_screen.dart';

const _testFood = SurplusFood(
  id: 't-1',
  merchantName: 'Roti O Bakso',
  name: 'Paket Roti Sisa Hari Ini',
  description: 'Isi 6 pcs roti.',
  originalPrice: 40000,
  discountPrice: 15000,
  quota: 4,
  pickupWindow: '19:00 - 21:00',
  category: FoodCategory.bakery,
);

Widget _wrapApp(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: child,
    ),
  );
}

List<Override> _fastRepo({Duration delay = const Duration(milliseconds: 10)}) {
  return [orderRepositoryProvider.overrideWithValue(FakeOrderRepository(delay: delay))];
}

Future<void> _scrollToButton(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Pesan Sekarang'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  testWidgets('validasi: pesan kosong menampilkan error pada field',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrapApp(const BookingScreen(food: _testFood), _fastRepo()));
    await tester.pumpAndSettle();

    await _scrollToButton(tester);

    // Field nama dikosongkan lalu tekan tombol Pesan.
    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tester.tap(find.text('Pesan Sekarang'));
    await tester.pumpAndSettle();

    expect(find.text('Nama pemesan wajib diisi.'), findsOneWidget);
  });

  testWidgets('validasi: nama kurang dari 3 karakter ditolak',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrapApp(const BookingScreen(food: _testFood), _fastRepo()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Wi');
    await _scrollToButton(tester);
    await tester.tap(find.text('Pesan Sekarang'));
    await tester.pumpAndSettle();

    expect(find.text('Nama minimal 3 karakter.'), findsOneWidget);
  });

  testWidgets('validasi: jumlah melebihi kuota ditolak',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrapApp(const BookingScreen(food: _testFood), _fastRepo()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'William');
    await tester.enterText(find.byType(TextFormField).at(1), '99');
    await _scrollToButton(tester);
    await tester.tap(find.text('Pesan Sekarang'));
    await tester.pumpAndSettle();

    expect(find.text('Melebihi kuota yang tersedia (maks. 4).'), findsOneWidget);
  });

  testWidgets('state loading: tombol non-aktif & berputar saat submit (anti double-tap)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrapApp(
        const BookingScreen(food: _testFood),
        _fastRepo(delay: const Duration(seconds: 30)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'William');
    await _scrollToButton(tester);
    await tester.tap(find.text('Pesan Sekarang'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200)); // masih loading (delay 30 detik)

    // Saat loading: muncul indikator putar & teks "Sedang memproses pesanan...".
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Sedang memproses pesanan...'), findsOneWidget);
    // Tombol sedang non-aktif (onPressed null) sehingga double tap diabaikan.
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);

    // Bersihkan timer tersisa supaya test bisa selesai dengan rapi.
    await tester.pumpAndSettle();
  });

  testWidgets('state sukses: kode pick-up ditampilkan setelah submit berhasil',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrapApp(const BookingScreen(food: _testFood), _fastRepo()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'William');
    await _scrollToButton(tester);
    await tester.tap(find.text('Pesan Sekarang'));
    await tester.pumpAndSettle();

    expect(find.text('Pesanan Berhasil! 🎉'), findsOneWidget);
    expect(find.text('RESCUE-101'), findsOneWidget);
    expect(find.text('Kembali ke Katalog'), findsOneWidget);
  });
}

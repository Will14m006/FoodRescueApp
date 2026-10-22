// Integration test: alur lengkap P5 dari booking sampai riwayat pesanan.
//
// Mensimulasikan apa yang kamu lakukan manual: login -> pilih makanan ->
// isi form -> tekan "Pesan Sekarang" -> buka Riwayat Pesanan -> cek apakah
// pesanannya muncul. Kalau test ini gagal, berarti ada bug di alurnya.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:food_rescue_app/main.dart';
import 'package:food_rescue_app/providers/booking_provider.dart';
import 'package:food_rescue_app/providers/catalog_provider.dart';
import 'package:food_rescue_app/repositories/order_repository.dart';
import 'package:food_rescue_app/repositories/surplus_food_repository.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('alur lengkap: booking -> pesanan masuk ke Riwayat Pesanan',
      (WidgetTester tester) async {
    await _pumpApp(tester);

    // 1. Login
    await tester.tap(find.descendant(
      of: find.byType(ElevatedButton),
      matching: find.text('Masuk'),
    ));
    await tester.pumpAndSettle();

    // 2. Katalog muncul; tunggu data selesai dimuat (lewati error pertama)
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();

    // 3. Pastikan katalog sudah ada isinya, lalu tekan tombol "Pesan" pertama
    expect(find.byType(ElevatedButton), findsWidgets);
    await tester.tap(find.text('Pesan').first);
    await tester.pumpAndSettle();

    // 4. Isi form booking
    await tester.enterText(find.byType(TextFormField).at(0), 'William');
    await tester.scrollUntilVisible(
      find.text('Pesan Sekarang'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Pesan Sekarang'));
    await tester.pumpAndSettle();

    // 5. Bottom sheet sukses harus muncul
    expect(find.text('Pesanan Berhasil! 🎉'), findsOneWidget);
    expect(find.text('RESCUE-101'), findsOneWidget);

    // 6. Kembali ke katalog
    await tester.tap(find.text('Kembali ke Katalog'));
    await tester.pumpAndSettle();

    // 7. Buka Status Pesanan dari ikon receipt di header dashboard
    await tester.tap(find.byIcon(Icons.receipt_long_rounded));
    await tester.pumpAndSettle();

    // 8. Pesanan HARUS muncul di status pesanan (masih pending)
    expect(find.text('Status Pesanan'), findsOneWidget);
    expect(find.text('Paket Roti Sisa Hari Ini'), findsOneWidget);
    expect(find.text('RESCUE-101'), findsOneWidget);
    expect(find.text('Sudah Pickup'), findsOneWidget);
    expect(find.text('Batalkan'), findsOneWidget);

    // 9. Tandai sudah pickup (Update status -> completed)
    await tester.tap(find.text('Sudah Pickup'));
    await tester.pumpAndSettle();
    expect(find.text('SELESAI'), findsOneWidget);
    expect(find.text('Hapus Pesanan'), findsOneWidget);

    // 10. Kembali, lalu buka Riwayat Pesanan (read-only)
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history_rounded));
    await tester.pumpAndSettle();

    // 11. Riwayat harus menampilkan pesanan dengan status yang sudah updated
    expect(find.text('Riwayat Pesanan'), findsOneWidget);
    expect(find.text('Paket Roti Sisa Hari Ini'), findsOneWidget);
    expect(find.text('RESCUE-101'), findsOneWidget);
    expect(find.text('SELESAI'), findsOneWidget);
    // Riwayat read-only: tidak boleh ada tombol aksi
    expect(find.text('Sudah Pickup'), findsNothing);
    expect(find.text('Batalkan'), findsNothing);
    expect(find.text('Hapus Pesanan'), findsNothing);
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        surplusFoodRepositoryProvider.overrideWithValue(
          FakeSurplusFoodRepository(
            simulateFailureOnFirstCall: true,
            delay: const Duration(milliseconds: 10),
          ),
        ),
        // P6: jangan tembak API asli saat test.
        orderRepositoryProvider.overrideWithValue(
          FakeOrderRepository(delay: const Duration(milliseconds: 10)),
        ),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: FoodRescueApp(),
      ),
    ),
  );
}

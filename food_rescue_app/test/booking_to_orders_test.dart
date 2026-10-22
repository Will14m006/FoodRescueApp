// Integration test: alur lengkap P5 dari booking sampai riwayat pesanan.
//
// Mensimulasikan apa yang kamu lakukan manual: login -> pilih makanan ->
// isi form -> tekan "Pesan Sekarang" -> buka Riwayat Pesanan -> cek apakah
// pesanannya muncul. Kalau test ini gagal, berarti ada bug di alurnya.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:food_rescue_app/main.dart';
import 'package:food_rescue_app/models/order_model.dart';
import 'package:food_rescue_app/providers/auth_provider.dart';
import 'package:food_rescue_app/providers/booking_provider.dart';
import 'package:food_rescue_app/providers/camera_provider.dart';
import 'package:food_rescue_app/providers/catalog_provider.dart';
import 'package:food_rescue_app/providers/location_provider.dart';
import 'package:food_rescue_app/providers/orders_provider.dart';
import 'package:food_rescue_app/repositories/auth_repository.dart';
import 'package:food_rescue_app/repositories/order_repository.dart';
import 'package:food_rescue_app/repositories/surplus_food_repository.dart';

/// P7: fake auth supaya test tidak memanggil API login.
class _FakeAuthRepo implements AuthRepository {
  @override
  Future<AuthUser> login({required String username, required String password}) async {
    return const AuthUser(
      id: 1,
      name: 'William',
      email: 'william@test.com',
      token: 'token-test',
    );
  }
}

/// P7: fake kamera supaya test tidak membuka kamera asli.
/// Memakai PNG 1x1 asli agar widget Image.memory bisa decode.
class _FakeCameraRepo implements CameraRepository {
  static final _png = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  @override
  Future<CameraResult> takePhoto() async => CameraResult(bytes: _png);
}

/// P7: fake lokasi supaya test tidak meminta izin GPS.
class _FakeLocationRepo implements LocationRepository {
  @override
  Future<LocationResult> getCurrentPosition() async =>
      const LocationResult(permission: LocationPermissionState.granted);

  @override
  Future<bool> openAppSettings() async => true;
}

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

    // Dialog konfirmasi pesanan.
    expect(find.text('Konfirmasi Pesanan'), findsOneWidget);
    await tester.tap(find.text('Ya, Pesan'));
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
    // P7: kini ada dialog bukti foto kamera. Kamera di-mock agar test jalan.
    await tester.tap(find.text('Sudah Pickup'));
    await tester.pumpAndSettle();
    expect(find.text('Bukti Pengambilan'), findsOneWidget);

    await tester.tap(find.text('Ambil Foto'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Konfirmasi'));
    await tester.pumpAndSettle();

    expect(find.text('SELESAI'), findsOneWidget);
    // Pesanan tidak bisa dihapus user — tidak ada tombol hapus.
    expect(find.text('Hapus Pesanan'), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);

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

  testWidgets('2 pesanan: keduanya bisa ditandai pickup (tidak tabrakan id)',
      (WidgetTester tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    Order order(String id) => Order(
          id: id,
          pickupCode: 'RESCUE-$id',
          buyerName: 'William',
          surplusFoodName: 'Roti',
          quantity: 1,
          totalPrice: 10000,
          status: OrderStatus.pending,
          createdAt: DateTime(2026, 10, 20),
        );

    await container.read(ordersProvider.notifier).addOrder(order('ord-209-aaa'));
    await container.read(ordersProvider.notifier).addOrder(order('ord-209-bbb'));

    await container.read(ordersProvider.notifier).markCompleted('ord-209-aaa');

    final orders = container.read(ordersProvider).requireValue;
    expect(orders, hasLength(2));
    // Hanya pesanan pertama yang selesai; yang kedua tetap pending.
    expect(orders.firstWhere((o) => o.id == 'ord-209-aaa').status,
        OrderStatus.completed);
    expect(orders.firstWhere((o) => o.id == 'ord-209-bbb').status,
        OrderStatus.pending);

    // Pesanan kedua masih bisa diubah.
    await container.read(ordersProvider.notifier).markCompleted('ord-209-bbb');
    final after = container.read(ordersProvider).requireValue;
    expect(after.every((o) => o.status == OrderStatus.completed), isTrue);
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
        // P7: fake auth & lokasi (advanced feature).
        authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
        locationRepositoryProvider.overrideWithValue(_FakeLocationRepo()),
        cameraRepositoryProvider.overrideWithValue(_FakeCameraRepo()),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: FoodRescueApp(),
      ),
    ),
  );
}

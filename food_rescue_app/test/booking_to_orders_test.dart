// Integration test: alur lengkap dari katalog sampai status pesanan.
//
// Mensimulasikan pemakaian nyata: sesi tersimpan -> dashboard pembeli ->
// pilih makanan -> pesan -> kode pick-up muncul -> status pesanan -> lampirkan
// bukti foto. Semua jaringan diganti fake in-memory.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_rescue_app/main.dart';
import 'package:food_rescue_app/models/order_model.dart';
import 'package:food_rescue_app/providers/camera_provider.dart';
import 'package:food_rescue_app/providers/catalog_provider.dart';
import 'package:food_rescue_app/providers/orders_provider.dart';
import 'package:food_rescue_app/repositories/order_repository.dart';
import 'package:food_rescue_app/repositories/surplus_food_repository.dart';

import 'support/fakes.dart';

/// PNG 1x1 asli agar `Image.memory` bisa decode.
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

Future<void> _pumpApp(WidgetTester tester, FakeOrderRepository orders) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...await sessionOverrides(),
        surplusFoodRepositoryProvider.overrideWithValue(
          FakeSurplusFoodRepository(
            simulateFailureOnFirstCall: false,
            delay: const Duration(milliseconds: 10),
          ),
        ),
        orderRepositoryProvider.overrideWithValue(orders),
        cameraRepositoryProvider.overrideWithValue(_FakeCameraRepo()),
      ],
      child: const FoodRescueApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('alur lengkap: pesan -> kode pick-up -> status -> bukti foto',
      (WidgetTester tester) async {
    final repo = FakeOrderRepository(delay: const Duration(milliseconds: 10));
    await _pumpApp(tester, repo);

    // 1. Dashboard pembeli tampil (sesi dipulihkan, tanpa layar login).
    expect(find.textContaining('katalog surplus hari ini'), findsOneWidget);

    // 2. Pilih makanan pertama.
    await tester.tap(find.text('Pesan').first);
    await tester.pumpAndSettle();

    // 3. Isi jumlah lalu pesan (nama tidak ditanyakan lagi).
    await tester.enterText(find.byType(TextFormField).at(0), '2');
    await tester.scrollUntilVisible(
      find.text('Pesan Sekarang'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Pesan Sekarang'));
    await tester.pumpAndSettle();

    expect(find.text('Konfirmasi Pesanan'), findsOneWidget);
    await tester.tap(find.text('Ya, Pesan'));
    await tester.pumpAndSettle();

    // 4. Kode pick-up dari server tampil.
    expect(find.textContaining('Pesanan Berhasil'), findsOneWidget);
    expect(find.textContaining('RESCUE-'), findsWidgets);
    expect(repo.createCalls, 1);
    expect(repo.lastQuantity, 2);

    // 5. Kembali ke katalog.
    await tester.tap(find.text('Kembali ke Katalog'));
    await tester.pumpAndSettle();

    // 6. Buka Status Pesanan.
    await tester.tap(find.byIcon(Icons.receipt_long_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Status Pesanan'), findsOneWidget);
    expect(find.text('Paket Roti Sisa Hari Ini'), findsOneWidget);
    expect(find.text('MENUNGGU'), findsOneWidget);
    // Pembeli tidak punya tombol selesai, itu hak merchant.
    expect(find.text('Verifikasi & Selesai'), findsNothing);
    expect(find.text('Bukti Pickup'), findsOneWidget);
    expect(find.text('Batalkan'), findsOneWidget);

    // 7. Lampirkan bukti foto: status TIDAK berubah jadi selesai.
    await tester.tap(find.text('Bukti Pickup'));
    await tester.pumpAndSettle();
    expect(find.text('Bukti Pengambilan'), findsOneWidget);

    await tester.tap(find.text('Ambil Foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Konfirmasi'));
    await tester.pumpAndSettle();

    expect(find.text('MENUNGGU'), findsOneWidget);
    expect(find.text('SELESAI'), findsNothing);

    // 8. Riwayat pesanan read-only menampilkan pesanan yang sama.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Riwayat Pesanan'), findsOneWidget);
    expect(find.text('Paket Roti Sisa Hari Ini'), findsOneWidget);

    // 9. Server tetap sumber kebenaran: pesanan masih pending.
    expect((await repo.fetchOrders(token: testUser.token)).single.status,
        OrderStatus.pending);
  });

  test('merchant menyelesaikan pesanan hanya dengan kode yang benar', () async {
    final repo = FakeOrderRepository(delay: Duration.zero);
    final order = await repo.createOrder(
      token: testUser.token,
      foodId: 1,
      quantity: 1,
    );

    final wrong = await repo
        .complete(
          token: 'token-merchant',
          orderId: order.id,
          pickupCode: 'SALAH',
        )
        .then<Object?>((o) => o)
        .catchError((Object e) => e);
    expect(wrong, isA<Exception>());

    final done = await repo.complete(
      token: 'token-merchant',
      orderId: order.id,
      pickupCode: order.pickupCode!,
    );
    expect(done.status, OrderStatus.completed);
  });

  test('pembatalan mengembalikan status ke cancelled (kuota diurus server)',
      () async {
    final repo = FakeOrderRepository(delay: Duration.zero);
    final order = await repo.createOrder(
      token: testUser.token,
      foodId: 1,
      quantity: 3,
    );

    final cancelled = await repo.cancel(
      token: testUser.token,
      orderId: order.id,
    );

    expect(cancelled.status, OrderStatus.cancelled);
  });

  test('fetchOrders mengembalikan pesanan terbaru lebih dulu', () async {
    final repo = FakeOrderRepository(delay: Duration.zero);
    final first = await repo.createOrder(
      token: testUser.token,
      foodId: 1,
      quantity: 1,
    );
    final second = await repo.createOrder(
      token: testUser.token,
      foodId: 2,
      quantity: 1,
    );

    final orders = await repo.fetchOrders(token: testUser.token);

    expect(orders.map((o) => o.id), [second.id, first.id]);
  });
}


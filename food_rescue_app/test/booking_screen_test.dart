// Widget test Fitur 2: Booking.
//
// Alur baru: nama tidak lagi diketik (server memakai nama akun), harga
// dihitung server. Yang diuji: validasi jumlah, konfirmasi, anti double-tap,
// dan layar sukses berisi kode pick-up dari server.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_rescue_app/models/surplus_food_model.dart';
import 'package:food_rescue_app/providers/auth_provider.dart';
import 'package:food_rescue_app/providers/orders_provider.dart';
import 'package:food_rescue_app/repositories/auth_repository.dart';
import 'package:food_rescue_app/repositories/order_repository.dart';
import 'package:food_rescue_app/screens/booking_screen.dart';
import 'package:food_rescue_app/widgets/primary_button.dart';

import 'support/fakes.dart';

const _testFood = SurplusFood(
  id: 1,
  merchantName: 'Roti O Bakso',
  name: 'Paket Roti Sisa Hari Ini',
  description: 'Isi 6 pcs roti.',
  originalPrice: 40000,
  discountPrice: 15000,
  quota: 4,
  pickupWindow: '19:00 - 21:00',
  category: FoodCategory.bakery,
);

class _LoggedInNotifier extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => testUser;
}

Widget _wrapApp(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(debugShowCheckedModeBanner: false, home: child),
  );
}

List<Override> _overrides({
  Duration delay = const Duration(milliseconds: 10),
}) =>
    [
      orderRepositoryProvider.overrideWithValue(FakeOrderRepository(delay: delay)),
      authProvider.overrideWith(_LoggedInNotifier.new),
    ];

Future<void> _tapOrder(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Pesan Sekarang'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Pesan Sekarang'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('validasi: jumlah kosong ditolak', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrapApp(const BookingScreen(food: _testFood), _overrides()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '');
    await _tapOrder(tester);

    expect(find.textContaining('wajib diisi'), findsOneWidget);
    // Dialog konfirmasi tidak boleh muncul kalau validasi gagal.
    expect(find.text('Konfirmasi Pesanan'), findsNothing);
  });

  testWidgets('validasi: jumlah melebihi kuota ditolak',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrapApp(const BookingScreen(food: _testFood), _overrides()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '9');
    await _tapOrder(tester);

    expect(find.textContaining('maksimal'), findsOneWidget);
    expect(find.text('Konfirmasi Pesanan'), findsNothing);
  });

  testWidgets('batal di dialog konfirmasi: tidak ada pesanan dibuat',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = FakeOrderRepository(delay: const Duration(milliseconds: 10));
    await tester.pumpWidget(
      _wrapApp(
        const BookingScreen(food: _testFood),
        [
          orderRepositoryProvider.overrideWithValue(repo),
          authProvider.overrideWith(_LoggedInNotifier.new),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _tapOrder(tester);
    expect(find.text('Konfirmasi Pesanan'), findsOneWidget);

    await tester.tap(find.text('Periksa Lagi'));
    await tester.pumpAndSettle();

    // Tetap di form, layar sukses tidak muncul.
    expect(find.text('KODE PICK-UP'), findsNothing);
    expect(repo.createCalls, 0);
  });

  testWidgets('sukses: kode pick-up dari server ditampilkan',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = FakeOrderRepository(delay: const Duration(milliseconds: 10));
    await tester.pumpWidget(
      _wrapApp(
        const BookingScreen(food: _testFood),
        [
          orderRepositoryProvider.overrideWithValue(repo),
          authProvider.overrideWith(_LoggedInNotifier.new),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _tapOrder(tester);
    await tester.tap(find.text('Ya, Pesan'));
    await tester.pumpAndSettle();

    expect(find.text('KODE PICK-UP'), findsOneWidget);
    expect(find.textContaining('RESCUE-'), findsWidgets);
    expect(repo.createCalls, 1);
    expect(repo.lastQuantity, 1);
  });

  testWidgets('loading: tombol nonaktif saat request berjalan (anti double-tap)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = FakeOrderRepository(delay: const Duration(seconds: 2));
    await tester.pumpWidget(
      _wrapApp(
        const BookingScreen(food: _testFood),
        [
          orderRepositoryProvider.overrideWithValue(repo),
          authProvider.overrideWith(_LoggedInNotifier.new),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _tapOrder(tester);
    await tester.tap(find.text('Ya, Pesan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Saat loading, PrimaryButton menonaktifkan dirinya (onPressed = null),
    // jadi tap kedua diabaikan Flutter.
    final loadingButton = tester.widget<PrimaryButton>(
      find.byType(PrimaryButton),
    );
    expect(loadingButton.isLoading, isTrue);

    await tester.pumpAndSettle();
    expect(repo.createCalls, 1);
  });
}

// P8: widget test untuk layout adaptif, keyboard-safe UI, aksesibilitas,
// dan umpan balik aksi.
//
// Catatan: test ini memakai fake repository (auth, lokasi, katalog) supaya
// tidak butuh internet, GPS, atau kamera.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_rescue_app/main.dart';
import 'package:food_rescue_app/providers/auth_provider.dart';
import 'package:food_rescue_app/providers/catalog_provider.dart';
import 'package:food_rescue_app/providers/location_provider.dart';
import 'package:food_rescue_app/repositories/auth_repository.dart';
import 'package:food_rescue_app/repositories/surplus_food_repository.dart';
import 'package:food_rescue_app/widgets/circle_icon_button.dart';
import 'package:food_rescue_app/widgets/responsive_body.dart';

class _FakeAuthRepo implements AuthRepository {
  @override
  Future<AuthUser> login({
    required String username,
    required String password,
  }) async {
    return const AuthUser(
      id: 1,
      name: 'William',
      email: 'william@test.com',
      token: 'token-test',
    );
  }
}

class _FakeLocationRepo implements LocationRepository {
  @override
  Future<LocationResult> getCurrentPosition() async =>
      const LocationResult(permission: LocationPermissionState.granted);

  @override
  Future<bool> openAppSettings() async => true;
}

Future<void> _pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
        locationRepositoryProvider.overrideWithValue(_FakeLocationRepo()),
        surplusFoodRepositoryProvider.overrideWithValue(
          FakeSurplusFoodRepository(
            simulateFailureOnFirstCall: false,
            delay: const Duration(milliseconds: 10),
          ),
        ),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: FoodRescueApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _loginButton =>
    find.descendant(of: find.byType(ElevatedButton), matching: find.text('Masuk'));

void main() {
  testWidgets('layout adaptif: layar kecil = 1 kolom, layar lebar = 2 kolom',
      (WidgetTester tester) async {
    // HP sempit.
    await _pumpApp(tester, const Size(400, 900));
    await tester.tap(_loginButton);
    await tester.pumpAndSettle();

    final smallGrid = tester.widget<GridView>(find.byType(GridView).first);
    final smallDelegate = smallGrid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
    // maxCrossAxisExtent > lebar layar -> hanya 1 kolom.
    expect(smallDelegate.maxCrossAxisExtent, greaterThanOrEqualTo(400));

    // Desktop lebar.
    tester.view.physicalSize = const Size(1400, 1000);
    await tester.pumpAndSettle();

    final wideGrid = tester.widget<GridView>(find.byType(GridView).first);
    final wideDelegate = wideGrid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
    // Konten dibatasi 1100px, jadi ada lebih dari satu kolom.
    expect(wideDelegate.maxCrossAxisExtent, lessThan(1400));
  });

  testWidgets('layout adaptif: konten dibatasi lebar di layar besar',
      (WidgetTester tester) async {
    await _pumpApp(tester, const Size(1600, 1000));
    await tester.tap(_loginButton);
    await tester.pumpAndSettle();

    expect(find.byType(ResponsiveBody), findsWidgets);

    final body = tester.getSize(
      find.descendant(
        of: find.byType(ResponsiveBody).first,
        matching: find.byType(ConstrainedBox),
      ).first,
    );
    expect(body.width, lessThanOrEqualTo(1100));
  });

  testWidgets('keyboard-safe: field tetap terlihat saat keyboard muncul',
      (WidgetTester tester) async {
    await _pumpApp(tester, const Size(400, 800));

    // Simulasikan keyboard naik 300px (viewInsets bawah).
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    // Scroll ke field password & pastikan masih bisa dijangkau (terlihat).
    await tester.scrollUntilVisible(
      find.byType(TextFormField).last,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final fieldRect = tester.getRect(find.byType(TextFormField).last);
    final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(fieldRect.bottom, lessThanOrEqualTo(screenHeight));
    expect(fieldRect.top, greaterThanOrEqualTo(0));
  });

  testWidgets('aksesibilitas: tombol ikon punya tooltip & target sentuh 48px',
      (WidgetTester tester) async {
    await _pumpApp(tester, const Size(800, 1400));
    await tester.tap(_loginButton);
    await tester.pumpAndSettle();

    final buttons = find.byType(CircleIconButton);
    expect(buttons, findsWidgets);

    for (final element in buttons.evaluate()) {
      final button = element.widget as CircleIconButton;
      expect(button.tooltip, isNotEmpty);
    }

    // Target sentuh minimal 48x48.
    final size = tester.getSize(buttons.first);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('aksesibilitas: field form punya label untuk screen reader',
      (WidgetTester tester) async {
    await _pumpApp(tester, const Size(400, 900));

    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Email / Username'), findsWidgets);
    expect(find.bySemanticsLabel('Password'), findsWidgets);
    semantics.dispose();
  });

  testWidgets('feedback aksi: menu profil tanpa layar memberi pesan, tidak diam',
      (WidgetTester tester) async {
    await _pumpApp(tester, const Size(800, 1400));
    await tester.tap(_loginButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bantuan'));
    await tester.pumpAndSettle();

    expect(find.textContaining('segera hadir'), findsOneWidget);
  });
}

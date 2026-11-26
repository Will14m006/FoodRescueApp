// P8: widget test untuk layout adaptif, keyboard-safe UI, aksesibilitas,
// dan umpan balik aksi.
//
// Sesi diisi di memori supaya aplikasi langsung masuk dashboard pembeli
// (tanpa layar login). Login diuji terpisah di widget_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_rescue_app/main.dart';
import 'package:food_rescue_app/providers/catalog_provider.dart';
import 'package:food_rescue_app/providers/orders_provider.dart';
import 'package:food_rescue_app/repositories/order_repository.dart';
import 'package:food_rescue_app/repositories/surplus_food_repository.dart';
import 'package:food_rescue_app/widgets/circle_icon_button.dart';
import 'package:food_rescue_app/widgets/responsive_body.dart';

import 'support/fakes.dart';

Future<void> _pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
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
        orderRepositoryProvider.overrideWithValue(
          FakeOrderRepository(delay: Duration.zero),
        ),
      ],
      child: const FoodRescueApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('layout adaptif: HP sempit tetap satu kolom, layar lebar lebih',
      (WidgetTester tester) async {
    await _pumpApp(tester, const Size(400, 900));

    final smallGrid = tester.widget<GridView>(find.byType(GridView).first);
    final smallDelegate =
        smallGrid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
    expect(smallDelegate.maxCrossAxisExtent, greaterThanOrEqualTo(400));

    tester.view.physicalSize = const Size(1400, 1000);
    await tester.pumpAndSettle();

    final wideGrid = tester.widget<GridView>(find.byType(GridView).first);
    final wideDelegate =
        wideGrid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
    expect(wideDelegate.maxCrossAxisExtent, lessThan(1400));
  });

  testWidgets('layout adaptif: konten dibatasi lebar di layar besar',
      (WidgetTester tester) async {
    await _pumpApp(tester, const Size(1600, 1000));

    expect(find.byType(ResponsiveBody), findsWidgets);

    final body = tester.getSize(
      find
          .descendant(
            of: find.byType(ResponsiveBody).first,
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(body.width, lessThanOrEqualTo(1100));
  });

  testWidgets('keyboard-safe: kolom pencarian tetap terlihat saat keyboard naik',
      (WidgetTester tester) async {
    await _pumpApp(tester, const Size(400, 800));

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    final field = find.byType(TextField).first;
    final rect = tester.getRect(field);
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    expect(rect.bottom, lessThanOrEqualTo(screenHeight));
    expect(rect.top, greaterThanOrEqualTo(0));
  });

  testWidgets('aksesibilitas: tombol ikon punya tooltip & target sentuh 48px',
      (WidgetTester tester) async {
    await _pumpApp(tester, const Size(800, 1600));

    final buttons = find.byType(CircleIconButton);
    expect(buttons, findsWidgets);

    for (final element in buttons.evaluate()) {
      final button = element.widget as CircleIconButton;
      expect(button.tooltip, isNotEmpty);
    }

    final size = tester.getSize(buttons.first);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('aksesibilitas: card makanan punya satu label ringkas',
      (WidgetTester tester) async {
    await _pumpApp(tester, const Size(800, 1600));

    final semantics = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel(RegExp('Paket Roti Sisa Hari Ini dari')),
      findsWidgets,
    );
    semantics.dispose();
  });

  testWidgets('feedback aksi: menu yang belum ada memberi pesan, tidak diam',
      (WidgetTester tester) async {
    await _pumpApp(tester, const Size(800, 1600));

    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bantuan'));
    await tester.pumpAndSettle();

    expect(find.textContaining('segera hadir'), findsOneWidget);
  });
}

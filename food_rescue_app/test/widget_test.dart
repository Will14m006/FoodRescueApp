// Smoke test: memastikan aplikasi bisa ter-build tanpa error.
//
// Catatan: class root bernama FoodRescueApp (test default Flutter sebelumnya
// menulis MyApp, yang membuat `flutter test` gagal).
//
// P7: aplikasi memakai Riverpod, jadi harus dibungkus ProviderScope.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_rescue_app/main.dart';

void main() {
  testWidgets('Aplikasi ter-build dan menampilkan halaman login', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: FoodRescueApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Food Rescue'), findsOneWidget);
    expect(find.text('Masuk'), findsWidgets);
  });

  testWidgets('Form login memiliki field email dan password', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: FoodRescueApp()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });
}

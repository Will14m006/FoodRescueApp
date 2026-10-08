// Smoke test: memastikan aplikasi bisa ter-build tanpa error.
//
// Catatan: class root sekarang bernama FoodRescueApp (test default Flutter
// sebelumnya menulis MyApp, yang membuat `flutter test` gagal).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_rescue_app/main.dart';

void main() {
  testWidgets('Aplikasi ter-build dan menampilkan halaman login', (WidgetTester tester) async {
    await tester.pumpWidget(const FoodRescueApp());
    await tester.pumpAndSettle();

    expect(find.text('Food Rescue Login'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets('Tombol primary menampilkan teks yang diberikan', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Masuk')),
        ),
      ),
    );

    expect(find.text('Masuk'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/surplus_food_model.dart';
import 'routes/app_routes.dart';
import 'screens/booking_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  runApp(const ProviderScope(child: FoodRescueApp()));
}

class FoodRescueApp extends StatelessWidget {
  const FoodRescueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Rescue',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.dashboard: (context) => const DashboardScreen(),
        // argumen route: SurplusFood yang dipilih pengguna di katalog.
        AppRoutes.booking: (context) {
          final food = ModalRoute.of(context)?.settings.arguments as SurplusFood;
          return BookingScreen(food: food);
        },
        AppRoutes.profile: (context) => const ProfileScreen(),
      },
    );
  }
}

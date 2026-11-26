import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/session/session_store.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_log.dart';
import 'models/surplus_food_model.dart';
import 'providers/auth_provider.dart';
import 'routes/app_routes.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/booking_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/merchant_dashboard_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/order_status_screen.dart';
import 'screens/profile_form_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  // P10: log runtime. Error tak tertangani dicatat supaya masalah saat
  // aplikasi berjalan (release) tetap bisa dilacak dari logcat/console.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        AppLog.error(
          'FlutterError: ${details.exceptionAsString()}',
          details.exception,
          details.stack,
        );
        FlutterError.presentError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        AppLog.error('Uncaught platform error', error, stack);
        return true;
      };

      // SharedPreferences dibuka sekali di awal supaya sesi sudah tersedia
      // saat frame pertama; kalau tidak, layar login sempat berkedip sebelum
      // sesi lama dipulihkan.
      final prefs = SharedPreferencesAsync();

      AppLog.info('Aplikasi start (debug=$kDebugMode)');
      runApp(
        ProviderScope(
          overrides: [
            sessionStoreProvider.overrideWithValue(SessionStore(prefs: prefs)),
          ],
          child: const FoodRescueApp(),
        ),
      );
    },
    (error, stack) => AppLog.error('Uncaught zone error', error, stack),
  );
}

class FoodRescueApp extends StatelessWidget {
  const FoodRescueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Rescue',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.home,
      // P10: log setiap perpindahan halaman — berguna saat tracing bug
      // "kenapa saya berakhir di layar ini".
      navigatorObservers: [AppRouteLogger()],
      routes: {
        AppRoutes.login: (context) => const LoginScreen(),
        // Layar awal dipilih dari peran di token (buyer/merchant/admin).
        AppRoutes.home: (context) => const HomeScreen(),
        AppRoutes.dashboard: (context) => const DashboardScreen(),
        AppRoutes.merchantFoods: (context) => const MerchantDashboardScreen(),
        AppRoutes.adminUsers: (context) => const AdminDashboardScreen(),
        // argumen route: SurplusFood yang dipilih pengguna di katalog.
        AppRoutes.booking: (context) {
          final food = ModalRoute.of(context)?.settings.arguments as SurplusFood;
          return BookingScreen(food: food);
        },
        AppRoutes.profile: (context) => const ProfileScreen(),
        AppRoutes.profileEdit: (context) => const ProfileFormScreen(),
        AppRoutes.orders: (context) => const OrdersScreen(),
        AppRoutes.orderStatus: (context) => const OrderStatusScreen(),
      },
    );
  }
}

/// Mencatat navigasi ke [AppLog] supaya urutan layar bisa direkonstruksi.
class AppRouteLogger extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppLog.info('push ${route.settings.name ?? route.runtimeType}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppLog.info('pop ${route.settings.name ?? route.runtimeType}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    AppLog.info(
      'replace ${oldRoute?.settings.name} -> ${newRoute?.settings.name}',
    );
  }
}

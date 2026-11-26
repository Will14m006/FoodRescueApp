import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../models/user_role.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import 'admin_dashboard_screen.dart';
import 'dashboard_screen.dart';
import 'merchant_dashboard_screen.dart';

/// Penentu layar awal sesuai peran yang tersimpan di token.
///
/// Server yang menentukan peran; aplikasi hanya menampilkan. Kalau merchant
/// membuka layar buyer lewat URL/route, backend tetap menolak request-nya
/// dengan 403 — jadi menyembunyikan menu bukan satu-satunya pengaman.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);

    return authAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Gagal memuat sesi: $error'),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (_) => false,
                  ),
                  child: const Text('Kembali ke halaman masuk'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          // Sesi berakhir (token kedaluwarsa): kembali ke login.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.login,
              (_) => false,
            );
          });
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return switch (user.role) {
          UserRole.merchant => const MerchantDashboardScreen(),
          UserRole.admin => const AdminDashboardScreen(),
          UserRole.buyer => const DashboardScreen(),
        };
      },
    );
  }
}

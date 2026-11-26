import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../providers/admin_provider.dart';
import '../repositories/admin_repository.dart';
import '../routes/app_routes.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/responsive_body.dart';
import 'admin/admin_foods_tab.dart';
import 'admin/admin_orders_tab.dart';
import 'admin/admin_users_tab.dart';

/// Dashboard admin: angka sistem, daftar user, katalog lintas toko, pesanan.
///
/// Admin **tidak** bisa mengubah peran siapa pun dari sini — backend tidak
/// menyediakan endpoint itu, dan memang seharusnya tidak. Yang bisa: meninjau
/// data dan menangguhkan akun yang menyalahgunakan aplikasi.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _Header(),
              const ResponsiveBody(maxWidth: 900, child: _StatsStrip()),
              const TabBar(
                tabs: [
                  Tab(text: 'Pengguna'),
                  Tab(text: 'Makanan'),
                  Tab(text: 'Pesanan'),
                ],
              ),
              const Expanded(
                child: ResponsiveBody(
                  maxWidth: 900,
                  child: TabBarView(
                    children: [
                      AdminUsersTab(),
                      AdminFoodsTab(),
                      AdminOrdersTab(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_rounded,
              color: AppColors.textOnPrimary, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Dashboard Admin',
              style: AppTextStyles.bodyStrong.copyWith(
                color: AppColors.textOnPrimary,
                fontSize: 15,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Segarkan',
            onPressed: () {
              ref.invalidate(adminStatsProvider);
              ref.invalidate(adminUsersProvider);
              ref.invalidate(adminFoodsProvider);
              ref.invalidate(adminOrdersProvider);
            },
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textOnPrimary, size: 22),
          ),
          const SizedBox(width: AppSpacing.xs),
          CircleIconButton(
            icon: Icons.person_rounded,
            tooltip: 'Profil',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
          ),
        ],
      ),
    );
  }
}

/// Enam angka ringkas, dua baris. Kartu yang bisa ditekan membuka tab terkait
/// supaya admin tidak perlu mencari manual.
class _StatsStrip extends ConsumerWidget {
  const _StatsStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return statsAsync.when(
      loading: () => const SizedBox(
        height: 76,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          '$error',
          style: AppTextStyles.caption.copyWith(color: AppColors.error),
        ),
      ),
      data: (stats) => _StatsGrid(stats: stats),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final cards = [
      (label: 'Pengguna', value: '${stats.totalUsers}', emoji: '👥'),
      (label: 'Toko', value: '${stats.stores}', emoji: '🏪'),
      (label: 'Makanan', value: '${stats.activeFoods}', emoji: '🍱'),
      (label: 'Pesanan', value: '${stats.totalOrders}', emoji: '🧾'),
      (
        label: 'Porsi terselamatkan',
        value: '${stats.portionsSaved}',
        emoji: '🌱'
      ),
      (label: 'Pendapatan', value: Formatters.rupiah(stats.revenue), emoji: '💵'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 640 ? 3 : 2;
          final width = (constraints.maxWidth - (columns - 1) * AppSpacing.sm) /
              columns;

          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final card in cards)
                SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm + 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(card.emoji,
                                style: const TextStyle(fontSize: 15)),
                            const SizedBox(width: 4),
                            Text(card.label, style: AppTextStyles.caption),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          card.value,
                          style: AppTextStyles.bodyStrong.copyWith(fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

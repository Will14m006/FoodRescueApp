import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../models/user_role.dart';
import '../providers/admin_provider.dart';
import '../repositories/admin_repository.dart';
import '../routes/app_routes.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/responsive_body.dart';

/// Dashboard admin: angka sistem + daftar user.
///
/// Admin **tidak** bisa mengubah peran siapa pun dari sini — backend tidak
/// menyediakan endpoint itu, dan memang seharusnya tidak.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_rounded,
                          color: AppColors.textOnPrimary, size: 22),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Dashboard Admin',
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: AppColors.textOnPrimary,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      CircleIconButton(
                        icon: Icons.person_rounded,
                        tooltip: 'Profil',
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.profile),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md + 4),
                  Text(
                    'Ringkasan Food Rescue',
                    style: AppTextStyles.display.copyWith(
                      color: AppColors.textOnPrimary,
                      fontSize: 24,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ResponsiveBody(
                maxWidth: 900,
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(adminStatsProvider);
                    ref.invalidate(adminUsersProvider);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.xxl + 40,
                    ),
                    children: [
                      statsAsync.when(
                        loading: () => const SizedBox(
                          height: 90,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (error, stack) => Text(
                          error.toString(),
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.error),
                        ),
                        data: (stats) => _AdminStatsView(stats: stats),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Pengguna',
                        style: AppTextStyles.bodyStrong.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const _UserList(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminStatsView extends StatelessWidget {
  const _AdminStatsView({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final cards = [
      (label: 'Pengguna', value: '${stats.totalUsers}', emoji: '👥'),
      (label: 'Toko', value: '${stats.stores}', emoji: '🏪'),
      (label: 'Makanan aktif', value: '${stats.activeFoods}', emoji: '🍱'),
      (label: 'Pesanan', value: '${stats.totalOrders}', emoji: '🧾'),
      (label: 'Pendapatan', value: Formatters.rupiah(stats.revenue), emoji: '💵'),
      (label: 'Sisa porsi', value: '${stats.remainingQuota}', emoji: '📦'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 3 : 2;
        final width =
            (constraints.maxWidth - (columns - 1) * AppSpacing.sm) / columns;

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        card.value,
                        style: AppTextStyles.bodyStrong.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(card.label, style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _UserList extends ConsumerWidget {
  const _UserList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersProvider);
    final filter = ref.watch(adminUserFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final role in <UserRole?>[
                null,
                UserRole.buyer,
                UserRole.merchant,
                UserRole.admin,
              ])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(role?.label ?? 'Semua'),
                    selected: filter == role,
                    showCheckmark: false,
                    onSelected: (_) =>
                        ref.read(adminUserFilterProvider.notifier).state = role,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        usersAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stack) => Text(
            error.toString(),
            style: AppTextStyles.caption.copyWith(color: AppColors.error),
          ),
          data: (users) {
            if (users.isEmpty) {
              return Text(
                'Tidak ada pengguna pada filter ini.',
                style: AppTextStyles.caption,
              );
            }

            return Column(
              children: [
                for (final user in users) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style:
                                    AppTextStyles.bodyStrong.copyWith(fontSize: 14),
                              ),
                              Text(user.email, style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            user.role.label,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

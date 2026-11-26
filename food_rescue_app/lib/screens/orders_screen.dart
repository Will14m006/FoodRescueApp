import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../providers/orders_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/order_card.dart';
import '../widgets/responsive_body.dart';

/// P5: Riwayat Pesanan — read-only.
///
/// Layar ini HANYA menampilkan data dari local storage. Tidak ada aksi ubah
/// status atau hapus; aksi Update ada di Status Pesanan.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _HistoryHeader(),
            Expanded(
              child: ResponsiveBody(
                maxWidth: 720,
                child: ordersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => EmptyStateView(
                    emoji: '❌',
                    title: 'Gagal Memuat',
                    message: 'Terjadi kesalahan saat memuat pesanan.',
                    actionLabel: 'Coba Lagi',
                    onAction: () => ref.read(ordersProvider.notifier).refresh(),
                  ),
                  data: (orders) {
                    if (orders.isEmpty) {
                      return EmptyStateView(
                        emoji: '🧾',
                        title: 'Belum Ada Riwayat',
                        message:
                            'Riwayat pesanan kamu akan muncul di sini dan tersimpan permanen di perangkat.',
                        actionLabel: 'Lihat Status Pesanan',
                        onAction: () => Navigator.pushNamed(
                          context,
                          AppRoutes.orderStatus,
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.lg + 4,
                        AppSpacing.xl,
                        AppSpacing.xxl + 40,
                      ),
                      itemCount: orders.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.md + 2),
                      // Tanpa `actions` -> card read-only.
                      itemBuilder: (context, index) =>
                          OrderCard(order: orders[index]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg + 4,
        AppSpacing.xl,
        AppSpacing.xxl + 4,
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
          CircleIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Kembali',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Riwayat Pesanan',
            style: AppTextStyles.headline.copyWith(color: AppColors.textOnPrimary),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            'Semua pesanan akun ini, langsung dari server',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textOnPrimary.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

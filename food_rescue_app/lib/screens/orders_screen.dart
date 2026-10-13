import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../models/order_model.dart';
import '../providers/orders_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/empty_state_view.dart';

/// P5: Local Data & Persistence — Riwayat Pesanan (read-only).
///
/// Layar ini HANYA untuk melihat data pesanan yang tersimpan di local storage.
/// Tidak ada aksi hapus / ubah status di sini — pengguna tidak boleh mengubah
/// atau menghapus riwayatnya. Aksi Update & Delete ada di Status Pesanan.
///
/// Data tetap tersimpan walaupun aplikasi ditutup dan dibuka lagi.
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
            // === Header ===
            Container(
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
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm + 2),
                      decoration: BoxDecoration(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.textOnPrimary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Riwayat Pesanan',
                    style: AppTextStyles.headline
                        .copyWith(color: AppColors.textOnPrimary),
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  Text(
                    'Tersimpan di perangkat kamu — tetap ada setelah aplikasi ditutup',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // === Daftar riwayat (read-only) ===
            Expanded(
              child: ordersAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
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
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _HistoryOrderCard(order: order);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card riwayat pesanan — murni menampilkan data, tanpa aksi apapun.
class _HistoryOrderCard extends StatelessWidget {
  final Order order;

  const _HistoryOrderCard({required this.order});

  Color get _statusColor => Color(order.status.colorValue);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.surplusFoodName,
                    style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    order.status.label,
                    style: AppTextStyles.base.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              'Atas nama: ${order.buyerName}  •  ${order.quantity} porsi',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            Row(
              children: [
                Text(
                  'Total: Rp ${order.totalPrice}',
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: AppSpacing.md + 2),
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      order.pickupCode,
                      style: AppTextStyles.base.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              _formatDate(order.createdAt),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textHint,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    return '${d.day}/${d.month}/${d.year} • ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} WIB';
  }
}

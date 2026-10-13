import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../models/order_model.dart';
import '../providers/orders_provider.dart';
import '../widgets/empty_state_view.dart';

/// P5: Status Pesanan.
///
/// Di layar ini pengguna melihat status pesanannya dan bisa melakukan aksi:
/// - tandai sudah diambil (Update -> completed)
/// - batalkan pesanan (Update -> cancelled)
///
/// Aksi Update (CRUD) memang berada di sini, BUKAN di Riwayat Pesanan.
/// Riwayat Pesanan sifatnya read-only (hanya lihat data tersimpan).
class OrderStatusScreen extends ConsumerWidget {
  const OrderStatusScreen({super.key});

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
                    'Status Pesanan',
                    style: AppTextStyles.headline
                        .copyWith(color: AppColors.textOnPrimary),
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  Text(
                    'Pantau & kelola pesanan kamu di sini',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // === Daftar status pesanan ===
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
                    return const EmptyStateView(
                      emoji: '📦',
                      title: 'Belum Ada Pesanan Aktif',
                      message:
                          'Pesanan yang kamu buat akan muncul di sini. Kamu bisa membatalkan atau menandainya sudah diambil.',
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
                      final isActive = order.status == OrderStatus.pending;

                      return _StatusOrderCard(
                        order: order,
                        // Aksi Update hanya muncul untuk pesanan yang masih pending.
                        onComplete: isActive
                            ? () => ref
                                .read(ordersProvider.notifier)
                                .markCompleted(order.id)
                            : null,
                        onCancel: isActive
                            ? () => ref
                                .read(ordersProvider.notifier)
                                .markCancelled(order.id)
                            : null,
                        // Aksi Delete hanya untuk pesanan yang sudah selesai /
                        // dibatalkan (pembersihan). Pesanan pending tidak bisa
                        // dihapus sebelum ditandai selesai/dibatalkan.
                        onDelete: !isActive
                            ? () => ref
                                .read(ordersProvider.notifier)
                                .deleteOrder(order.id)
                            : null,
                      );
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

class _StatusOrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

  const _StatusOrderCard({
    required this.order,
    required this.onComplete,
    required this.onCancel,
    required this.onDelete,
  });

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
            const SizedBox(height: AppSpacing.md),
            // Aksi Update: hanya untuk pesanan yang masih pending.
            if (onComplete != null || onCancel != null)
              Row(
                children: [
                  if (onComplete != null)
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Sudah Pickup',
                        color: AppColors.primary,
                        onTap: onComplete!,
                      ),
                    ),
                  if (onComplete != null && onCancel != null)
                    const SizedBox(width: AppSpacing.sm),
                  if (onCancel != null)
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.cancel_outlined,
                        label: 'Batalkan',
                        color: AppColors.error,
                        onTap: onCancel!,
                        isDestructive: true,
                      ),
                    ),
                ],
              )
            else if (onDelete != null)
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.delete_outline_rounded,
                      label: 'Hapus Pesanan',
                      color: AppColors.textSecondary,
                      onTap: onDelete!,
                    ),
                  ),
                ],
              )
            else
              Text(
                'Pesanan ini sudah ${order.status == OrderStatus.completed ? 'diambil' : 'dibatalkan'} — tidak bisa diubah lagi.',
                style: AppTextStyles.caption.copyWith(
                  fontStyle: FontStyle.italic,
                  color: AppColors.textHint,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDestructive
              ? AppColors.errorLight
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTextStyles.base.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/ui/app_feedback.dart';
import '../models/order_model.dart';
import '../providers/orders_provider.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/order_card.dart';
import '../widgets/pickup_proof_dialog.dart';
import '../widgets/responsive_body.dart';

/// P7: Status Pesanan.
///
/// Di layar ini pengguna melihat status pesanannya dan bisa melakukan aksi:
/// - tandai sudah diambil (Update -> completed) **dengan bukti foto kamera**
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
            const _StatusHeader(),
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
                        // Aksi Update hanya untuk pesanan pending. Pesanan
                        // TIDAK bisa dihapus user — riwayat permanen.
                        final isActive = order.status == OrderStatus.pending;

                        return OrderCard(
                          order: order,
                          actions: isActive
                              ? _OrderActions(order: order)
                              : null,
                        );
                      },
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

class _StatusHeader extends StatelessWidget {
  const _StatusHeader();

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
            'Status Pesanan',
            style: AppTextStyles.headline.copyWith(color: AppColors.textOnPrimary),
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
    );
  }
}

/// P9: aksi Update dipisah jadi widget sendiri, terpisah dari card read-only.
class _OrderActions extends ConsumerWidget {
  final Order order;

  const _OrderActions({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.check_circle_outline_rounded,
            label: 'Sudah Pickup',
            color: AppColors.primary,
            onTap: () => _confirmPickup(context, ref, order),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ActionButton(
            icon: Icons.cancel_outlined,
            label: 'Batalkan',
            color: AppColors.error,
            onTap: () => _cancelOrder(context, ref, order),
            isDestructive: true,
          ),
        ),
      ],
    );
  }
}

/// P7 Advanced Feature #3 (Kamera): bukti foto sebelum menandai pickup.
Future<void> _confirmPickup(
  BuildContext context,
  WidgetRef ref,
  Order order,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => const PickupProofDialog(),
  );

  if (confirmed != true) return;

  await ref.read(ordersProvider.notifier).markCompleted(order.id);

  if (context.mounted) {
    AppFeedback.success(context, 'Pesanan ditandai sudah diambil.');
  }
}

/// P8: pembatalan minta konfirmasi + memberi umpan balik.
Future<void> _cancelOrder(
  BuildContext context,
  WidgetRef ref,
  Order order,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: const Text('Batalkan Pesanan'),
      content: Text(
        'Pesanan "${order.surplusFoodName}" akan dibatalkan dan tidak bisa '
        'dikembalikan. Lanjutkan?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Tidak'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.textOnPrimary,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Ya, Batalkan'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  await ref.read(ordersProvider.notifier).markCancelled(order.id);

  if (context.mounted) {
    AppFeedback.info(context, 'Pesanan dibatalkan.');
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
    // P8: tombol Material supaya ada ripple, label semantik, tinggi >= 44px.
    return SizedBox(
      height: 44,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(
          label,
          style: AppTextStyles.base.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: isDestructive
              ? AppColors.errorLight
              : color.withValues(alpha: 0.08),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}

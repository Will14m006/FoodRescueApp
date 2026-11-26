import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';
import 'dart:typed_data';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/ui/app_feedback.dart';
import '../models/order_model.dart';
import '../models/user_role.dart';
import '../providers/auth_provider.dart';
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
    final role = ref.watch(currentRoleProvider);

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
                    message: '$error',
                    actionLabel: 'Coba Lagi',
                    onAction: () => ref.read(ordersProvider.notifier).refresh(),
                  ),
                  data: (orders) {
                    if (orders.isEmpty) {
                      return EmptyStateView(
                        emoji: '📦',
                        title: 'Belum Ada Pesanan',
                        message: role == UserRole.merchant
                            ? 'Pesanan dari pembeli akan muncul di sini.'
                            : 'Pesanan yang kamu buat akan muncul di sini.',
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

                        return OrderCard(
                          order: order,
                          actions: !isActive
                              ? null
                              : role == UserRole.buyer
                                  ? _BuyerActions(order: order)
                                  : _StaffActions(order: order),
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

/// Aksi untuk pembeli: lampirkan bukti foto (lokal), atau batalkan.
///
/// Pembeli **tidak** menandai pesanan selesai — itu hak merchant yang
/// memverifikasi kode. Server menolak `complete` dari token pembeli.
class _BuyerActions extends ConsumerWidget {
  final Order order;

  const _BuyerActions({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.camera_alt_outlined,
            label: 'Bukti Pickup',
            color: AppColors.primary,
            onTap: () => _attachProof(context, ref, order),
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

/// Aksi untuk merchant/admin: verifikasi kode pick-up atau batalkan.
class _StaffActions extends ConsumerWidget {
  final Order order;

  const _StaffActions({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.check_circle_outline_rounded,
            label: 'Verifikasi & Selesai',
            color: AppColors.primary,
            onTap: () => _verifyCode(context, ref, order),
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

/// Bukti foto pengambilan hanya untuk pembeli dan **tidak** mengubah status:
/// status ditentukan merchant lewat kode pick-up.
Future<void> _attachProof(
  BuildContext context,
  WidgetRef ref,
  Order order,
) async {
  final photo = await showDialog<Uint8List>(
    context: context,
    builder: (dialogContext) => const PickupProofDialog(),
  );
  if (photo == null) return;

  try {
    await ref
        .read(ordersProvider.notifier)
        .attachProof(order.id, base64Encode(photo));
  } on Exception catch (e) {
    if (context.mounted) {
      AppFeedback.error(context, 'Gagal menyimpan bukti: $e');
    }
    return;
  }

  if (context.mounted) {
    AppFeedback.success(
      context,
      'Bukti tersimpan di perangkat. Tunjukkan kode ke merchant.',
    );
  }
}

Future<void> _verifyCode(
  BuildContext context,
  WidgetRef ref,
  Order order,
) async {
  final controller = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: const Text('Verifikasi Pick-up'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Minta kode dari ${order.buyerName}, lalu masukkan di sini.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'RESCUE-XXXXXXXX'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () =>
              Navigator.pop(dialogContext, controller.text.trim()),
          child: const Text('Selesai'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (code == null || code.isEmpty || !context.mounted) return;

  try {
    await ref.read(ordersProvider.notifier).complete(
          orderId: order.id,
          pickupCode: code,
        );
    if (context.mounted) AppFeedback.success(context, 'Pesanan selesai.');
  } on Exception catch (e) {
    if (context.mounted) AppFeedback.error(context, '$e');
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

  try {
    await ref.read(ordersProvider.notifier).cancel(order.id);
    if (context.mounted) AppFeedback.info(context, 'Pesanan dibatalkan.');
  } on Exception catch (e) {
    if (context.mounted) AppFeedback.error(context, '$e');
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

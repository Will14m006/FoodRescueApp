import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../models/order_model.dart';

/// P9: satu widget card pesanan untuk Status Pesanan & Riwayat Pesanan.
///
/// Sebelumnya dua layar punya card hampir identik (duplikasi ±60 baris).
/// Bedanya hanya aksi opsional di bagian bawah.
class OrderCard extends StatelessWidget {
  /// Aksi Update (Sudah Pickup / Batalkan). Null = card read-only (riwayat).
  final Widget? actions;
  final Order order;

  const OrderCard({super.key, required this.order, this.actions});

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
            _buildHeader(),
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              'Atas nama: ${order.buyerName}  •  ${order.quantity} porsi',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            _buildPriceRow(),
            // P10 fix #3: bukti pengambilan bisa dilihat lagi setelah pickup.
            if (order.proofPhoto != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _ProofThumb(base64Photo: order.proofPhoto!),
            ],
            if (actions != null) ...[
              const SizedBox(height: AppSpacing.md),
              actions!,
            ] else ...[
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                Formatters.dateTime(order.createdAt),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textHint,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
        StatusBadge(label: order.status.label, color: _statusColor),
      ],
    );
  }

  Widget _buildPriceRow() {
    return Row(
      children: [
        Text(
          'Total: ${Formatters.rupiah(order.totalPrice)}',
          style: AppTextStyles.bodyStrong.copyWith(
            color: AppColors.primary,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: AppSpacing.md + 2),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
    );
  }
}

/// Thumbnail bukti pengambilan (P10 fix #3).
///
/// Foto disimpan sebagai base64 supaya tidak butuh file eksternal.
class _ProofThumb extends StatelessWidget {
  final String base64Photo;

  const _ProofThumb({required this.base64Photo});

  @override
  Widget build(BuildContext context) {
    final bytes = base64Decode(base64Photo);

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Image.memory(
            bytes,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const Icon(
              Icons.broken_image_outlined,
              size: 20,
              color: AppColors.textHint,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Bukti pengambilan',
          style: AppTextStyles.caption.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

/// Badge status (PENDING / COMPLETED / CANCELLED) — dipakai bersama.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.base.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

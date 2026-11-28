import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../models/surplus_food_model.dart';
import 'food_image.dart';

/// Card untuk satu item makanan surplus di katalog (Buyer Feed).
///
/// Desain: thumbnail gradient dengan emoji, badge diskon, rating, dan
/// harga diskon yang menonjol. Full-width di mobile, grid di desktop.
class FoodCard extends StatelessWidget {
  final SurplusFood food;
  final VoidCallback onBook;

  const FoodCard({super.key, required this.food, required this.onBook});

  @override
  Widget build(BuildContext context) {
    // P8 aksesibilitas: satu label ringkas supaya screen reader tidak
    // membacakan potongan-potongan teks card secara terpisah.
    return Semantics(
      label:
          '${food.name} dari ${food.merchantName}, ${food.formattedDiscountPrice}, '
          'sisa ${food.quota} porsi, ambil pukul ${food.pickupWindow}',
      button: false,
      child: Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDarker.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === Thumbnail ===
          Stack(
            children: [
              SizedBox(
                height: 150,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl),
                  ),
                  child: FoodImage(food: food),
                ),
              ),
              // Gradasi bawah supaya badge tetap terbaca di atas foto terang.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.xl),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.18),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.10),
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
              ),
              // Badge diskon
              Positioned(
                top: AppSpacing.sm + 2,
                left: AppSpacing.sm + 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '-${food.discountPercent}%',
                    style: AppTextStyles.base.copyWith(
                      color: AppColors.textOnPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              // Badge sisa porsi (data nyata dari server, bukan rating karangan)
              Positioned(
                top: AppSpacing.sm + 2,
                right: AppSpacing.sm + 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 12, color: AppColors.warning),
                      const SizedBox(width: 2),
                      Text(
                        '${food.quota}',
                        style: AppTextStyles.base.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // === Detail ===
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        food.merchantName,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.storefront_outlined, size: 12, color: AppColors.textHint),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  food.name,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 13, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        food.pickupWindow,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      food.formattedDiscountPrice,
                      style: AppTextStyles.bodyStrong.copyWith(
                        fontSize: 17,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      food.formattedOriginalPrice,
                      style: AppTextStyles.caption.copyWith(
                        decoration: TextDecoration.lineThrough,
                        decorationColor: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    // Sisa kuota
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: food.quota <= 2
                            ? AppColors.accentLight
                            : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        food.quota <= 2 ? 'Sisa ${food.quota}!' : 'Sisa ${food.quota}',
                        style: AppTextStyles.base.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: food.quota <= 2 ? AppColors.accentDark : AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Tombol pesan
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textOnPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        onPressed: onBook,
                        child: const Text(
                          'Pesan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

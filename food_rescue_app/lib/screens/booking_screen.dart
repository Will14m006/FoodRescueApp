import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../models/order_model.dart';
import '../models/surplus_food_model.dart';
import '../providers/booking_provider.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';

/// Fitur 2: Booking / Pemesanan makanan surplus.
///
/// Menerima [SurplusFood] lewat constructor. Form memakai `GlobalKey<FormState>`
/// untuk validasi input, dan tombol pesan memakai state loading dari
/// bookingProvider supaya tidak bisa di-tap dua kali saat submit berjalan.
class BookingScreen extends ConsumerStatefulWidget {
  final SurplusFood food;

  const BookingScreen({super.key, required this.food});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _noteController = TextEditingController();

  SurplusFood get food => widget.food;

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nama pemesan wajib diisi.';
    }
    if (value.trim().length < 3) {
      return 'Nama minimal 3 karakter.';
    }
    return null;
  }

  String? _validateQuantity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Jumlah pesanan wajib diisi.';
    }
    final qty = int.tryParse(value.trim());
    if (qty == null) {
      return 'Jumlah harus berupa angka.';
    }
    if (qty < 1) {
      return 'Minimal memesan 1 porsi.';
    }
    if (qty > food.quota) {
      return 'Melebihi kuota yang tersedia (maks. ${food.quota}).';
    }
    return null;
  }

  Future<void> _submit() async {
    // Validasi form: jika ada field gagal validasi, langsung stop & tampilkan error.
    if (!_formKey.currentState!.validate()) return;

    // Tutup keyboard supaya loading terlihat jelas.
    FocusScope.of(context).unfocus();

    await ref.read(bookingProvider.notifier).submit(
          buyerName: _nameController.text.trim(),
          surplusFoodId: food.id,
          surplusFoodName: food.name,
          quantity: int.parse(_qtyController.text.trim()),
          unitPrice: food.discountPrice,
        );
  }

  void _showSuccessSheet(Order order) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.xxl,
              AppSpacing.xxl,
              AppSpacing.xxxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Handle bar
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 44,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Pesanan Berhasil! 🎉', style: AppTextStyles.headline),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tunjukkan kode pick-up ini ke kasir saat mengambil makanan.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.xxl),
              // Kode pick-up
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xl,
                  horizontal: AppSpacing.xxl,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text('KODE PICK-UP', style: AppTextStyles.caption),
                    const SizedBox(height: AppSpacing.xs + 2),
                    Text(
                      order.pickupCode,
                      style: AppTextStyles.display.copyWith(
                        fontSize: 30,
                        color: AppColors.primaryDark,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Rincian
              _DetailRow(label: 'Makanan', value: order.surplusFoodName),
              _DetailRow(label: 'Jumlah', value: '${order.quantity} porsi'),
              _DetailRow(
                label: 'Total',
                value: 'Rp ${order.totalPrice}',
                valueColor: AppColors.primary,
                isBold: true,
              ),
              _DetailRow(label: 'Atas nama', value: order.buyerName),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                text: 'Kembali ke Katalog',
                icon: Icons.arrow_back_rounded,
                onPressed: () {
                  ref.read(bookingProvider.notifier).reset();
                  Navigator.pop(sheetContext);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(bookingProvider);

    // Dengarkan perubahan state: kalau ada Order baru (sukses), tampilkan bottom sheet.
    ref.listen<AsyncValue<Order?>>(bookingProvider, (previous, next) {
      next.whenData((order) {
        if (order != null && !orderAsync.isLoading) {
          _showSuccessSheet(order);
        }
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // === App bar kustom ===
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md + 2,
                AppSpacing.md + 2,
                AppSpacing.md + 2,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm + 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text('Pesan Makanan', style: AppTextStyles.title),
                ],
              ),
            ),

            // === Form ===
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md + 2,
                  AppSpacing.xl,
                  AppSpacing.xxl + 40,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kartu makanan
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(AppRadius.xl),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(food.emoji, style: const TextStyle(fontSize: 40)),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.md + 2),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(food.merchantName, style: AppTextStyles.caption),
                                    const SizedBox(height: 2),
                                    Text(
                                      food.name,
                                      style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(
                                          food.formattedOriginalPrice,
                                          style: AppTextStyles.caption.copyWith(
                                            decoration: TextDecoration.lineThrough,
                                            decorationColor: AppColors.textHint,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Text(
                                          food.formattedDiscountPrice,
                                          style: AppTextStyles.bodyStrong.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Info kuota & ambil
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md + 2),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 20, color: AppColors.warning),
                            const SizedBox(width: AppSpacing.sm + 2),
                            Expanded(
                              child: Text(
                                'Ambil pukul ${food.pickupWindow}. Sisa ${food.quota} porsi saja!',
                                style: AppTextStyles.body.copyWith(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),

                      Text('Detail Pemesanan', style: AppTextStyles.headline.copyWith(fontSize: 18)),
                      const SizedBox(height: AppSpacing.xl),
                      AppTextField(
                        label: 'Nama Pemesan',
                        hint: 'Masukkan nama kamu',
                        controller: _nameController,
                        validator: _validateName,
                        prefixIcon: Icons.person_outline_rounded,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        label: 'Jumlah Porsi (maks. ${food.quota})',
                        hint: '1',
                        controller: _qtyController,
                        validator: _validateQuantity,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.shopping_bag_outlined,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        label: 'Catatan (opsional)',
                        hint: 'Contoh: tanpa sambal',
                        controller: _noteController,
                        maxLines: 2,
                        prefixIcon: Icons.note_alt_outlined,
                      ),
                      const SizedBox(height: AppSpacing.xxl),

                      PrimaryButton(
                        text: 'Pesan Sekarang',
                        icon: Icons.shopping_cart_rounded,
                        isLoading: orderAsync.isLoading,
                        onPressed: _submit,
                      ),
                      if (orderAsync.isLoading) ...[
                        const SizedBox(height: AppSpacing.md),
                        Center(
                          child: Text(
                            'Sedang memproses pesanan...',
                            style: AppTextStyles.caption,
                          ),
                        ),
                      ],
                      if (orderAsync.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          child: Text(
                            'Gagal membuat pesanan: ${orderAsync.error}'
                                .replaceFirst('Exception: ', ''),
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body),
          Text(
            value,
            style: AppTextStyles.bodyStrong.copyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

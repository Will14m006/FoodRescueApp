import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/order_model.dart';
import '../models/surplus_food_model.dart';
import '../providers/booking_provider.dart';
import '../routes/app_routes.dart';
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

  void _showSuccessDialog(Order order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Pesanan Berhasil'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tunjukkan kode pick-up ini ke kasir:'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green, width: 1.5),
                ),
                child: Text(
                  order.pickupCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('${order.surplusFoodName} x ${order.quantity}'),
              Text('Total: Rp ${order.totalPrice}'),
              Text('Atas nama: ${order.buyerName}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Reset state & kembali ke katalog.
                ref.read(bookingProvider.notifier).reset();
                Navigator.pop(dialogContext);
                Navigator.popUntil(context, (route) => route.settings.name == AppRoutes.dashboard);
              },
              child: const Text('Kembali ke Katalog'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(bookingProvider);

    // Dengarkan perubahan state: kalau ada Order baru (sukses), tampilkan dialog.
    ref.listen<AsyncValue<Order?>>(bookingProvider, (previous, next) {
      next.whenData((order) {
        if (order != null && !orderAsync.isLoading) {
          _showSuccessDialog(order);
        }
      });
    });

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Pesan Makanan', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.fastfood, color: Colors.green, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                food.merchantName,
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                              Text(
                                food.name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    food.formattedOriginalPrice,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    food.formattedDiscountPrice,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Kuota tersisa: ${food.quota} porsi',
                                style: const TextStyle(fontSize: 12, color: Colors.orange),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Detail Pemesanan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Nama Pemesan',
                  controller: _nameController,
                  validator: _validateName,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Jumlah Porsi (maks. ${food.quota})',
                  controller: _qtyController,
                  validator: _validateQuantity,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Catatan (opsional)',
                  controller: _noteController,
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: 'Pesan Sekarang',
                  isLoading: orderAsync.isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 12),
                if (orderAsync.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Sedang memproses pesanan...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                if (orderAsync.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Gagal membuat pesanan: ${orderAsync.error}'.replaceFirst('Exception: ', ''),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

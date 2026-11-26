import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/ui/app_feedback.dart';
import '../core/utils/formatters.dart';
import '../models/order_model.dart';
import '../models/surplus_food_model.dart';
import '../providers/auth_provider.dart';
import '../providers/merchant_provider.dart';
import '../providers/orders_provider.dart';
import '../repositories/merchant_repository.dart';
import '../routes/app_routes.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/responsive_body.dart';

/// Dashboard merchant: toko, stok, dan pesanan yang harus diverifikasi.
class MerchantDashboardScreen extends ConsumerWidget {
  const MerchantDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(merchantProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(storeName: profileAsync.valueOrNull?.storeName, name: user?.name),
            Expanded(
              child: ResponsiveBody(
                maxWidth: 900,
                child: profileAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => EmptyStateView(
                    emoji: '⚠️',
                    title: 'Gagal memuat toko',
                    message: error.toString(),
                    actionLabel: 'Coba Lagi',
                    onAction: () => ref.invalidate(merchantProfileProvider),
                  ),
                  data: (profile) {
                    if (profile == null) {
                      return _SetupStoreForm(
                        onSaved: () => ref.invalidate(merchantProfileProvider),
                      );
                    }
                    return _MerchantBody(profile: profile);
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

class _Header extends ConsumerWidget {
  const _Header({required this.storeName, required this.name});

  final String? storeName;
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
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
              const Icon(Icons.storefront_rounded,
                  color: AppColors.textOnPrimary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Dashboard Merchant',
                style: AppTextStyles.bodyStrong.copyWith(
                  color: AppColors.textOnPrimary,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              CircleIconButton(
                icon: Icons.receipt_long_rounded,
                tooltip: 'Pesanan Masuk',
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.orderStatus),
              ),
              const SizedBox(width: AppSpacing.sm),
              CircleIconButton(
                icon: Icons.person_rounded,
                tooltip: 'Profil',
                onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md + 4),
          Text(
            storeName ?? 'Lengkapi profil toko',
            style: AppTextStyles.display.copyWith(
              color: AppColors.textOnPrimary,
              fontSize: 24,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            children: [
              const Icon(Icons.badge_outlined,
                  color: AppColors.textOnPrimary, size: 14),
              const SizedBox(width: 4),
              Text(
                'Masuk sebagai ${name ?? 'Merchant'}',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MerchantBody extends ConsumerWidget {
  const _MerchantBody({required this.profile});

  final MerchantProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(merchantStatsProvider);
    final ordersAsync = ref.watch(ordersProvider);
    final foodsAsync = ref.watch(merchantFoodsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(merchantStatsProvider);
        await ref.read(ordersProvider.notifier).refresh();
        await ref.read(merchantFoodsProvider.notifier).refresh();
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
            error: (error, stack) => _ErrorCard(message: error.toString()),
            data: (stats) => _StatsGrid(stats: stats),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(
            title: 'Perlu diverifikasi',
            subtitle: 'Minta kode pick-up dari pembeli, lalu tekan Selesai.',
          ),
          const SizedBox(height: AppSpacing.md),
          ordersAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => _ErrorCard(message: error.toString()),
            data: (orders) {
              final pending = orders
                  .where((o) => o.status == OrderStatus.pending)
                  .toList();
              if (pending.isEmpty) {
                return const _Hint('Tidak ada pesanan yang menunggu.');
              }
              return Column(
                children: [
                  for (final order in pending) ...[
                    _PendingOrderCard(order: order),
                    const SizedBox(height: AppSpacing.sm + 2),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(child: _SectionTitle(title: 'Stok makanan', subtitle: null)),
              TextButton.icon(
                onPressed: () => _showAddFoodSheet(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Tambah'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          foodsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => _ErrorCard(message: error.toString()),
            data: (foods) {
              if (foods.isEmpty) {
                return const _Hint(
                  'Belum ada makanan. Tambahkan makanan surplus pertama.',
                );
              }
              return Column(
                children: [
                  for (final food in foods) ...[
                    _FoodRow(food: food),
                    const SizedBox(height: AppSpacing.sm + 2),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final MerchantStats stats;

  @override
  Widget build(BuildContext context) {
    final cards = [
      (label: 'Pesanan', value: '${stats.totalOrders}', emoji: '🧾'),
      (label: 'Porsi terjual', value: '${stats.portionsSold}', emoji: '🍱'),
      (label: 'Pendapatan', value: Formatters.rupiah(stats.revenue), emoji: '💵'),
      (label: 'Sisa porsi', value: '${stats.remainingQuota}', emoji: '📦'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 4 : 2;
        final width =
            (constraints.maxWidth - (columns - 1) * AppSpacing.sm) / columns;

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final card in cards)
              SizedBox(width: width, child: _StatTile(
                emoji: card.emoji,
                label: card.label,
                value: card.value,
              )),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.emoji,
    required this.label,
    required this.value,
  });

  final String emoji;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTextStyles.bodyStrong.copyWith(fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _PendingOrderCard extends ConsumerWidget {
  const _PendingOrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
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
              Text(
                Formatters.rupiah(order.totalPrice),
                style: AppTextStyles.bodyStrong.copyWith(
                  color: AppColors.primary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${order.buyerName} · ${order.quantity} porsi · ${order.pickupCode}',
            style: AppTextStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _verify(context, ref, order),
                  icon: const Icon(Icons.qr_code_rounded, size: 18),
                  label: const Text('Verifikasi kode'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: () => _cancel(context, ref, order),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Batalkan'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _verify(BuildContext context, WidgetRef ref, Order order) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
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
      if (context.mounted) {
        AppFeedback.success(context, 'Pesanan ${order.pickupCode} selesai.');
      }
    } on Exception catch (e) {
      if (context.mounted) AppFeedback.error(context, '$e');
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batalkan Pesanan'),
        content: Text(
          'Batalkan pesanan ${order.pickupCode}? Kuota akan dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
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
}

class _FoodRow extends ConsumerWidget {
  const _FoodRow({required this.food});

  final SurplusFood food;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          Text(food.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${food.formattedDiscountPrice} · sisa ${food.quota}'
                  '${food.isActive ? '' : ' · nonaktif'}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showActions(context, ref),
            child: const Text('Kelola'),
          ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                food.name,
                style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Ubah stok'),
              onTap: () {
                Navigator.pop(sheetContext);
                _editQuota(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit detail'),
              onTap: () {
                Navigator.pop(sheetContext);
                _editDetail(context, ref);
              },
            ),
            ListTile(
              leading: Icon(
                food.isActive
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: food.isActive ? AppColors.error : AppColors.primary,
              ),
              title: Text(
                food.isActive ? 'Nonaktifkan' : 'Aktifkan kembali',
                style: TextStyle(
                  color: food.isActive ? AppColors.error : AppColors.primary,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _toggleActive(context, ref);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref) async {
    final makeActive = !food.isActive;

    if (!makeActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Nonaktifkan Makanan'),
          content: Text(
            '"${food.name}" akan hilang dari katalog pembeli. '
            'Pesanan yang sudah masuk tetap tersimpan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.textOnPrimary,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Nonaktifkan'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await ref
          .read(merchantFoodsProvider.notifier)
          .updateFood(foodId: food.id, isActive: makeActive);
      if (context.mounted) {
        AppFeedback.success(
          context,
          makeActive ? 'Makanan diaktifkan kembali.' : 'Makanan dinonaktifkan.',
        );
      }
    } on Exception catch (e) {
      if (context.mounted) AppFeedback.error(context, '$e');
    }
  }

  Future<void> _editDetail(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController(text: food.name);
    final description = TextEditingController(text: food.description);
    final original = TextEditingController(text: '${food.originalPrice}');
    final discount = TextEditingController(text: '${food.discountPrice}');
    final window = TextEditingController(text: food.pickupWindow);

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit makanan', style: AppTextStyles.headline),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama makanan'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Deskripsi'),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: original,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Harga asli'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: discount,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Harga diskon'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: window,
                decoration: const InputDecoration(labelText: 'Jam ambil'),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('Simpan Perubahan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (save != true) {
      for (final c in [name, description, original, discount, window]) {
        c.dispose();
      }
      return;
    }

    final originalPrice = int.tryParse(original.text.trim());
    final discountPrice = int.tryParse(discount.text.trim());
    final newName = name.text.trim();

    try {
      if (newName.length < 2) {
        throw StateError('Nama makanan minimal 2 karakter.');
      }
      if (originalPrice == null ||
          discountPrice == null ||
          discountPrice > originalPrice) {
        throw StateError('Harga tidak valid (diskon ≤ harga asli).');
      }
      if (window.text.trim().isEmpty) {
        throw StateError('Jam ambil tidak boleh kosong.');
      }

      await ref.read(merchantFoodsProvider.notifier).updateFood(
            foodId: food.id,
            name: newName,
            description: description.text.trim(),
            originalPrice: originalPrice,
            discountPrice: discountPrice,
            pickupWindow: window.text.trim(),
          );
      if (context.mounted) AppFeedback.success(context, 'Makanan diperbarui.');
    } on Exception catch (e) {
      if (context.mounted) AppFeedback.error(context, '$e');
    } finally {
      for (final c in [name, description, original, discount, window]) {
        c.dispose();
      }
    }
  }

  Future<void> _editQuota(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: '${food.quota}');
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Stok ${food.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Sisa porsi'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, int.tryParse(controller.text.trim())),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value < 0 || !context.mounted) return;

    try {
      await ref
          .read(merchantFoodsProvider.notifier)
          .updateQuota(food.id, value);
      if (context.mounted) AppFeedback.success(context, 'Stok diperbarui.');
    } on Exception catch (e) {
      if (context.mounted) AppFeedback.error(context, '$e');
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.bodyStrong.copyWith(fontSize: 16)),
        if (subtitle != null)
          Text(subtitle!, style: AppTextStyles.caption),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outline),
      ),
      child: Text(message, style: AppTextStyles.caption),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        message,
        style: AppTextStyles.caption.copyWith(color: AppColors.error),
      ),
    );
  }
}

/// Merchant baru wajib membuat profil toko dulu sebelum bisa menambah makanan.
class _SetupStoreForm extends ConsumerStatefulWidget {
  const _SetupStoreForm({required this.onSaved});

  final VoidCallback onSaved;

  @override
  ConsumerState<_SetupStoreForm> createState() => _SetupStoreFormState();
}

class _SetupStoreFormState extends ConsumerState<_SetupStoreForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(merchantProfileProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Buat profil toko', style: AppTextStyles.headline),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Nama toko tampil di katalog pembeli. Bisa diubah kapan saja.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama toko',
              hintText: 'Warung Bu Siti',
            ),
          ),
          if (state.hasError) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              state.error.toString(),
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton(
            onPressed: state.isLoading
                ? null
                : () async {
                    final name = _controller.text.trim();
                    if (name.length < 2) {
                      AppFeedback.error(context, 'Nama toko minimal 2 karakter.');
                      return;
                    }
                    await ref
                        .read(merchantProfileProvider.notifier)
                        .saveProfile(name);
                    if (!context.mounted) return;
                    if (ref.read(merchantProfileProvider).hasError) return;
                    AppFeedback.success(context, 'Toko "$name" dibuat.');
                    widget.onSaved();
                  },
            child: Text(state.isLoading ? 'Menyimpan...' : 'Simpan'),
          ),
        ],
      ),
    );
  }
}

Future<void> _showAddFoodSheet(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final description = TextEditingController();
  final original = TextEditingController(text: '25000');
  final discount = TextEditingController(text: '10000');
  final quota = TextEditingController(text: '5');
  final window = TextEditingController(text: '19:00 - 21:00');

  final save = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tambah makanan', style: AppTextStyles.headline),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama makanan'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Deskripsi'),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: original,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Harga asli'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: discount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Harga diskon'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quota,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Kuota'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: window,
                    decoration:
                        const InputDecoration(labelText: 'Jam ambil'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    ),
  );

  if (save != true) {
    for (final c in [name, description, original, discount, quota, window]) {
      c.dispose();
    }
    return;
  }

  final originalPrice = int.tryParse(original.text.trim());
  final discountPrice = int.tryParse(discount.text.trim());
  final quotaValue = int.tryParse(quota.text.trim());

  try {
    if (name.text.trim().length < 2) {
      throw StateError('Nama makanan minimal 2 karakter.');
    }
    if (originalPrice == null ||
        discountPrice == null ||
        quotaValue == null ||
        discountPrice > originalPrice) {
      throw StateError('Harga/kuota tidak valid (diskon ≤ harga asli).');
    }

    await ref.read(merchantFoodsProvider.notifier).create(
          name: name.text.trim(),
          description: description.text.trim(),
          originalPrice: originalPrice,
          discountPrice: discountPrice,
          quota: quotaValue,
          pickupWindow: window.text.trim().isEmpty
              ? '19:00 - 21:00'
              : window.text.trim(),
        );
    if (context.mounted) {
      AppFeedback.success(context, 'Makanan ditambahkan.');
      ref.invalidate(merchantStatsProvider);
    }
  } on Exception catch (e) {
    if (context.mounted) AppFeedback.error(context, '$e');
  } finally {
    for (final c in [name, description, original, discount, quota, window]) {
      c.dispose();
    }
  }
}

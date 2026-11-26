import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/order_model.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/order_card.dart';

/// Tab "Pesanan": semua pesanan lintas toko, dengan filter status.
class AdminOrdersTab extends ConsumerWidget {
  const AdminOrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(adminOrdersProvider);
    final filter = ref.watch(adminOrderFilterProvider);

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              for (final status in <OrderStatus?>[
                null,
                OrderStatus.pending,
                OrderStatus.completed,
                OrderStatus.cancelled,
              ])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Center(
                    child: ChoiceChip(
                      label: Text(status?.label ?? 'Semua'),
                      selected: filter == status,
                      showCheckmark: false,
                      onSelected: (_) => ref
                          .read(adminOrderFilterProvider.notifier)
                          .state = status,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminOrdersProvider),
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.error),
                  ),
                ),
              ),
              data: (orders) {
                if (orders.isEmpty) {
                  return ListView(
                    children: [
                      const SizedBox(height: 80),
                      Center(
                        child: Text(
                          'Tidak ada pesanan pada filter ini.',
                          style: AppTextStyles.caption,
                        ),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.xxl,
                  ),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.merchantName,
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        OrderCard(order: order),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

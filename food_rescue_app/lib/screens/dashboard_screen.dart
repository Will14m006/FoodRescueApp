import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../models/surplus_food_model.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/error_state_view.dart';
import '../widgets/food_card.dart';
import '../widgets/food_card_skeleton.dart';
import '../widgets/location_banner.dart';
import '../widgets/responsive_body.dart';

/// Fitur 1: Katalog Surplus (Buyer Feed).
///
/// State management memakai Riverpod. Layar ini hanya "membaca" state dari
/// catalogProvider dan menampilkan UI sesuai kondisinya:
///   - loading   -> skeleton shimmer
///   - data       -> daftar makanan (atau empty state kalau hasil filter 0)
///   - error      -> ErrorStateView dengan tombol Retry
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final category = ref.watch(selectedCategoryProvider);
    final userName = ref.watch(currentUserProvider)?.name ?? 'Food Rescuer';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // === Header ===
            _buildHeader(userName),
            // === Lokasi (advanced feature: GPS) ===
            const ResponsiveBody(maxWidth: 1100, child: LocationBanner()),
            // === Search bar ===
            _buildSearchBar(searchQuery),
            // === Filter kategori ===
            _buildCategoryChips(category),
            // === Konten utama ===
            Expanded(
              child: ResponsiveBody(
                maxWidth: 1100,
                child: catalogAsync.when(
                  loading: () => _buildSkeletonGrid(),
                  error: (error, stack) => ErrorStateView(
                    message: error.toString(),
                    onRetry: () => ref.read(catalogProvider.notifier).retry(),
                  ),
                  data: (foods) {
                    final filtered = _filter(foods, searchQuery, category);

                    if (filtered.isEmpty) {
                      return EmptyStateView(
                        emoji: searchQuery.isEmpty && category == FoodCategory.all
                            ? '🍽️'
                            : '🔍',
                        title: searchQuery.isEmpty && category == FoodCategory.all
                            ? 'Belum Ada Makanan Tersedia'
                            : 'Pencarian Tidak Ditemukan',
                        message: searchQuery.isEmpty && category == FoodCategory.all
                            ? 'Semua makanan surplus hari ini sudah terpesan. Coba lagi besok!'
                            : 'Tidak ada makanan yang cocok. Coba kata kunci atau kategori lain.',
                        actionLabel: searchQuery.isEmpty &&
                                category == FoodCategory.all
                            ? null
                            : 'Reset Filter',
                        onAction: searchQuery.isEmpty &&
                                category == FoodCategory.all
                            ? null
                            : () {
                                _clearSearch();
                                ref
                                    .read(selectedCategoryProvider.notifier)
                                    .state = FoodCategory.all;
                              },
                      );
                    }

                    return _buildFoodGrid(filtered);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String userName) {
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
              const Icon(Icons.eco_rounded, color: AppColors.textOnPrimary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Food Rescue',
                style: AppTextStyles.bodyStrong.copyWith(
                  color: AppColors.textOnPrimary,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              CircleIconButton(
                icon: Icons.receipt_long_rounded,
                tooltip: 'Status Pesanan',
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.orderStatus),
              ),
              const SizedBox(width: AppSpacing.sm),
              CircleIconButton(
                icon: Icons.history_rounded,
                tooltip: 'Riwayat Pesanan',
                onPressed: () => Navigator.pushNamed(context, AppRoutes.orders),
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
            'Selamatkan makanan,\nhemat hemat planet 🌍',
            style: AppTextStyles.display.copyWith(
              color: AppColors.textOnPrimary,
              fontSize: 24,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppColors.textOnPrimary, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Halo $userName · katalog surplus hari ini',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(String searchQuery) {
    return ResponsiveBody(
      maxWidth: 1100,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.sm,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.outline),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDarker.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: (value) =>
                ref.read(searchQueryProvider.notifier).state = value,
            decoration: InputDecoration(
              hintText: 'Cari makanan atau toko...',
              hintStyle: AppTextStyles.body.copyWith(
                color: AppColors.textHint,
                fontSize: 13,
              ),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 20, color: AppColors.textHint),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      tooltip: 'Hapus pencarian',
                      icon: const Icon(Icons.clear_rounded,
                          size: 18, color: AppColors.textHint),
                      onPressed: _clearSearch,
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(FoodCategory selected) {
    return ResponsiveBody(
      maxWidth: 1100,
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          itemCount: FoodCategory.values.length,
          separatorBuilder: (context, index) =>
              const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, index) {
            final cat = FoodCategory.values[index];
            final isSelected = cat == selected;

            return ChoiceChip(
              label: Text(cat.label),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) =>
                  ref.read(selectedCategoryProvider.notifier).state = cat,
              labelStyle: AppTextStyles.base.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppColors.textOnPrimary
                    : AppColors.textSecondary,
              ),
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primary,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.outline,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md + 2,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        crossAxisSpacing: AppSpacing.md + 2,
        mainAxisSpacing: AppSpacing.md + 2,
        childAspectRatio: 0.82,
      ),
      itemCount: 4,
      itemBuilder: (context, index) => const FoodCardSkeleton(),
    );
  }

  Widget _buildFoodGrid(List<SurplusFood> foods) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md + 2,
        AppSpacing.xl,
        AppSpacing.xxl + 60,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        crossAxisSpacing: AppSpacing.md + 2,
        mainAxisSpacing: AppSpacing.md + 2,
        childAspectRatio: 0.82,
      ),
      itemCount: foods.length,
      itemBuilder: (context, index) {
        final food = foods[index];
        return FoodCard(
          food: food,
          onBook: () => Navigator.pushNamed(
            context,
            AppRoutes.booking,
            arguments: food,
          ),
        );
      },
    );
  }

  List<SurplusFood> _filter(List<SurplusFood> foods, String query, FoodCategory category) {
    var result = foods;

    if (category != FoodCategory.all) {
      result = result.where((food) => food.category == category).toList();
    }

    if (query.isEmpty) return result;

    final keyword = query.toLowerCase();
    return result
        .where((food) =>
            food.name.toLowerCase().contains(keyword) ||
            food.merchantName.toLowerCase().contains(keyword))
        .toList();
  }
}

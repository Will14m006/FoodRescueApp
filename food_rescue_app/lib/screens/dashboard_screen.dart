import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/catalog_provider.dart';
import '../routes/app_routes.dart';
import '../models/surplus_food_model.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/error_state_view.dart';
import '../widgets/food_card.dart';

/// Fitur 1: Katalog Surplus (Buyer Feed).
///
/// State management memakai Riverpod. Layar ini hanya "membaca" state dari
/// catalogProvider dan menampilkan UI sesuai kondisinya:
///   - loading   -> indikator putar
///   - data       -> daftar makanan (atau empty state kalau hasil pencarian 0)
///   - error      -> ErrorStateView dengan tombol Retry
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Katalog Makanan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
              decoration: InputDecoration(
                hintText: 'Cari makanan atau nama toko...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: catalogAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => ErrorStateView(
                message: error.toString(),
                onRetry: () => ref.read(catalogProvider.notifier).retry(),
              ),
              data: (foods) {
                final filtered = _filter(foods, searchQuery);

                if (filtered.isEmpty) {
                  return EmptyStateView(
                    title: searchQuery.isEmpty ? 'Belum Ada Makanan Tersedia' : 'Pencarian Tidak Ditemukan',
                    message: searchQuery.isEmpty
                        ? 'Semua makanan surplus hari ini sudah terpesan. Coba lagi nanti!'
                        : 'Tidak ada makanan yang cocok dengan "$searchQuery".',
                    actionLabel: searchQuery.isEmpty ? null : 'Hapus Filter',
                    onAction: searchQuery.isEmpty
                        ? null
                        : () => ref.read(searchQueryProvider.notifier).state = '',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final food = filtered[index];
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
              },
            ),
          ),
        ],
      ),
    );
  }

  List<SurplusFood> _filter(List<SurplusFood> foods, String query) {
    if (query.isEmpty) return foods;

    final keyword = query.toLowerCase();
    return foods
        .where((food) =>
            food.name.toLowerCase().contains(keyword) ||
            food.merchantName.toLowerCase().contains(keyword))
        .toList();
  }
}

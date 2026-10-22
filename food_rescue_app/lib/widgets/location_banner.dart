import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../providers/location_provider.dart';

/// P7 Advanced Feature #2: banner lokasi di dashboard.
///
/// Menampilkan 4 kondisi:
///   - idle      -> tombol "Aktifkan lokasi" (izin belum diminta)
///   - loading   -> indikator memuat
///   - sukses    -> koordinat + tombol perbarui
///   - error     -> pesan izin + tombol pengaturan (kalau ditolak permanen)
class LocationBanner extends ConsumerWidget {
  const LocationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(locationProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      child: locationAsync.when(
        loading: () => Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Mencari lokasi kamu...', style: AppTextStyles.caption),
          ],
        ),
        error: (error, _) => Row(
          children: [
            const Icon(Icons.location_off_rounded,
                size: 18, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Gagal mengambil lokasi.',
                style: AppTextStyles.caption.copyWith(color: AppColors.error),
              ),
            ),
            TextButton(
              onPressed: () => ref.read(locationProvider.notifier).request(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
        data: (result) {
          // Idle: belum pernah minta izin.
          if (result == null) {
            return Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: AppColors.primaryDark),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Aktifkan lokasi untuk melihat titik jemput terdekat.',
                    style: AppTextStyles.caption,
                  ),
                ),
                TextButton(
                  onPressed: () => ref.read(locationProvider.notifier).request(),
                  child: const Text('Aktifkan'),
                ),
              ],
            );
          }

          // Sukses.
          if (result.hasPosition) {
            final pos = result.position!;
            return Row(
              children: [
                const Icon(Icons.my_location_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Lokasi aktif • ${pos.latitude.toStringAsFixed(4)}, '
                    '${pos.longitude.toStringAsFixed(4)}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Perbarui lokasi',
                  onPressed: () =>
                      ref.read(locationProvider.notifier).request(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                ),
              ],
            );
          }

          // Izin ditolak / GPS mati.
          final permanent =
              result.permission == LocationPermissionState.deniedForever;
          return Row(
            children: [
              const Icon(Icons.location_off_rounded,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  result.errorMessage ?? 'Lokasi tidak tersedia.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (permanent)
                TextButton(
                  onPressed: () =>
                      ref.read(locationProvider.notifier).openSettings(),
                  child: const Text('Pengaturan'),
                )
              else
                TextButton(
                  onPressed: () =>
                      ref.read(locationProvider.notifier).request(),
                  child: const Text('Coba'),
                ),
            ],
          );
        },
      ),
    );
  }
}

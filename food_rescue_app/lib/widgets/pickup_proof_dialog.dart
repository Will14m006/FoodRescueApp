import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../providers/camera_provider.dart';

/// P7 Advanced Feature #3: dialog bukti pengambilan dengan kamera.
///
/// Alur:
///   1. User menekan "Ambil Foto" -> izin kamera diminta
///   2. Foto tampil sebagai preview
///   3. "Konfirmasi" hanya aktif kalau foto sudah ada
///   4. User menutup kamera tanpa foto -> state batal, bukan error
class PickupProofDialog extends ConsumerWidget {
  const PickupProofDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraAsync = ref.watch(cameraProvider);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: const Text('Bukti Pengambilan'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
            'Ambil foto makanan yang kamu terima sebagai bukti pengambilan.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.outline),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: cameraAsync.when(
              loading: () => const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              error: (error, _) => Text(
                'Kamera gagal dibuka.',
                style: AppTextStyles.caption.copyWith(color: AppColors.error),
              ),
              data: (result) {
                if (result == null) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.photo_camera_outlined,
                          size: 32, color: AppColors.textHint),
                      const SizedBox(height: AppSpacing.xs),
                      Text('Belum ada foto', style: AppTextStyles.caption),
                    ],
                  );
                }

                if (result.hasPhoto) {
                  return Image.memory(
                    result.bytes!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  );
                }

                // Dibatalkan atau izin ditolak.
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    result.cancelled
                        ? 'Pengambilan foto dibatalkan.'
                        : (result.errorMessage ?? 'Kamera tidak tersedia.'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: result.cancelled
                          ? AppColors.textSecondary
                          : AppColors.error,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: cameraAsync.isLoading
                  ? null
                  : () => ref.read(cameraProvider.notifier).takePhoto(),
              icon: const Icon(Icons.photo_camera_rounded, size: 18),
              label: Text(
                cameraAsync.valueOrNull?.hasPhoto == true
                    ? 'Ambil Ulang'
                    : 'Ambil Foto',
              ),
            ),
          ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(cameraProvider.notifier).clear();
            Navigator.pop(context, false);
          },
          child: const Text('Batal'),
        ),
        ElevatedButton(
          // Konfirmasi hanya bisa ditekan kalau foto sudah diambil.
          onPressed: cameraAsync.valueOrNull?.hasPhoto == true
              ? () {
                  ref.read(cameraProvider.notifier).clear();
                  Navigator.pop(context, true);
                }
              : null,
          child: const Text('Konfirmasi'),
        ),
      ],
    );
  }
}

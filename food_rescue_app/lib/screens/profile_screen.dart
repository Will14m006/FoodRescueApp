import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/ui/app_feedback.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/responsive_body.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Keluar Akun'),
        content: const Text('Yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(authProvider.notifier).logout();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    }
  }

  /// P8: menu yang belum punya layar tetap memberi respons, tidak diam.
  void _comingSoon(BuildContext context, String feature) {
    AppFeedback.info(context, '$feature segera hadir di versi berikutnya.');
  }

  /// FAQ singkat — pertanyaan yang benar-benar muncul saat memakai aplikasi.
  void _showHelp(BuildContext context) {
    const faqs = [
      (
        'Bagaimana cara mengambil makanan?',
        'Pesan di katalog, tunjukkan KODE PICK-UP di Status Pesanan ke kasir '
            'toko, lalu merchant memverifikasi kodenya.',
      ),
      (
        'Kenapa kode pick-up saya tidak diterima?',
        'Kode berbeda untuk setiap pesanan. Pastikan kasir memasukkan kode '
            'dari pesanan yang benar — bukan kode pesanan lain.',
      ),
      (
        'Bisakah pesanan dibatalkan?',
        'Bisa, selama statusnya masih MENUNGGU. Kuota otomatis kembali ke '
            'toko. Pesanan yang sudah selesai tidak bisa dibatalkan.',
      ),
      (
        'Kenapa akun saya tidak bisa login?',
        'Akun bisa ditangguhkan admin bila menyalahgunakan aplikasi. '
            'Hubungi admin lewat email di halaman Tentang.',
      ),
      (
        'Apakah foto bukti pengambilan dikirim ke server?',
        'Tidak. Foto hanya disimpan di perangkatmu sebagai pengingat pribadi.',
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text('Pusat Bantuan', style: AppTextStyles.headline),
            const SizedBox(height: AppSpacing.md),
            for (final faq in faqs) ...[
              Text(faq.$1, style: AppTextStyles.bodyStrong),
              const SizedBox(height: 4),
              Text(faq.$2, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Food Rescue',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.eco_rounded,
          size: 40, color: AppColors.primary),
      applicationLegalese: 'Proyek Akhir PBL Pemrograman Mobile\n'
          'Menyelamatkan makanan surplus, mengurangi limbah pangan.',
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          'Dibangun dengan Flutter (Dart) dan backend Dart sendiri: '
          'shelf + drift (SQLite) + bcrypt + JWT.',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // === Header ===
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg + 4,
                AppSpacing.xl,
                AppSpacing.xxxl + 4,
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
                children: [
                  Row(
                    children: [
                      Text(
                        'Profil',
                        style: AppTextStyles.headline.copyWith(color: AppColors.textOnPrimary),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Notifikasi',
                        onPressed: () => _comingSoon(context, 'Notifikasi'),
                        icon: const Icon(
                          Icons.notifications_rounded,
                          color: AppColors.textOnPrimary,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.textOnPrimary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.textOnPrimary,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md + 2),
                  Text(
                    user?.name ?? 'Pengguna',
                    style: AppTextStyles.headline.copyWith(color: AppColors.textOnPrimary),
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  Text(
                    user?.email ?? 'Belum login',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textOnPrimary.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.textOnPrimary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      user?.role.label ?? '-',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textOnPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // === Statistik (dari server, bukan angka karangan) ===
            ResponsiveBody(
              maxWidth: 720,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg + 4,
                  AppSpacing.xl,
                  AppSpacing.md + 2,
                ),
                child: Row(
                  children: [
                    _StatCard(
                      emoji: '🧾',
                      value: '${ref.watch(ordersProvider).valueOrNull?.length ?? 0}',
                      label: 'Total Pesanan',
                    ),
                    const SizedBox(width: AppSpacing.md + 2),
                    _StatCard(
                      emoji: '📦',
                      value: '${ref.watch(activeOrdersProvider).length}',
                      label: 'Sedang Berjalan',
                    ),
                  ],
                ),
              ),
            ),

            // === Menu ===
            Expanded(
              // P8: ListView (bukan Column + Spacer) supaya layar kecil tidak
              // overflow dan menu tetap bisa di-scroll.
              child: ResponsiveBody(
                maxWidth: 720,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  children: [
                    _MenuTile(
                      icon: Icons.edit_rounded,
                      title: 'Edit Profil',
                      subtitle: 'Ubah nama & email kamu',
                      onTap: () async {
                        await Navigator.pushNamed(
                          context,
                          AppRoutes.profileEdit,
                        );
                      },
                    ),
                    _MenuTile(
                      icon: Icons.lock_reset_rounded,
                      title: 'Ubah Password',
                      subtitle: 'Ganti password akun',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.changePassword,
                      ),
                    ),
                    _MenuTile(
                      icon: Icons.delivery_dining_rounded,
                      title: 'Status Pesanan',
                      subtitle: 'Pantau & kelola pesanan aktif',
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.orderStatus),
                    ),
                    _MenuTile(
                      icon: Icons.receipt_long_rounded,
                      title: 'Riwayat Pesanan',
                      subtitle: 'Lihat semua pesanan kamu (read-only)',
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.orders),
                    ),
                    _MenuTile(
                      icon: Icons.location_on_rounded,
                      title: 'Alamat',
                      subtitle: 'Atur alamat pengambilan',
                      onTap: () => _comingSoon(context, 'Pengaturan alamat'),
                    ),
                    _MenuTile(
                      icon: Icons.notifications_rounded,
                      title: 'Notifikasi',
                      subtitle: 'Atur preferensi notifikasi',
                      onTap: () => _comingSoon(context, 'Pengaturan notifikasi'),
                    ),
                    _MenuTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Bantuan',
                      subtitle: 'Pusat bantuan & FAQ',
                      onTap: () => _showHelp(context),
                    ),
                    _MenuTile(
                      icon: Icons.info_outline_rounded,
                      title: 'Tentang Aplikasi',
                      subtitle: 'Versi 1.0.0',
                      onTap: () => _showAbout(context),
                    ),
                    _MenuTile(
                      icon: Icons.logout_rounded,
                      title: 'Keluar',
                      subtitle: 'Logout dari akun ini',
                      onTap: () => _logout(context, ref),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Food Rescue App • PBL Pemrograman Mobile',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;

  const _StatCard({
    required this.emoji,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: AppSpacing.xs + 2),
            Text(value, style: AppTextStyles.bodyStrong.copyWith(fontSize: 16)),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // P8: Material + InkWell = ripple feedback, target sentuh penuh,
    // dan otomatis terbaca sebagai tombol oleh screen reader.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.all(AppSpacing.md + 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 19, color: AppColors.primaryDark),
                ),
                const SizedBox(width: AppSpacing.md + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.bodyStrong),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textHint,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

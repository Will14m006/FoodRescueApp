import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/ui/app_feedback.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_role.dart';
import '../../providers/admin_provider.dart';
import '../../repositories/admin_repository.dart';

/// Tab "Pengguna": cari, filter peran, tangguhkan akun, lihat detail.
class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(adminUserSearchProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);
    final filter = ref.watch(adminUserFilterProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari nama atau email...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(adminUserSearchProvider.notifier).state = '';
                        setState(() {});
                      },
                    ),
            ),
            onChanged: (value) {
              ref.read(adminUserSearchProvider.notifier).state = value;
              setState(() {});
            },
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              for (final role in <UserRole?>[
                null,
                UserRole.buyer,
                UserRole.merchant,
                UserRole.admin,
              ])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Center(
                    child: ChoiceChip(
                      label: Text(role?.label ?? 'Semua'),
                      selected: filter == role,
                      showCheckmark: false,
                      onSelected: (_) => ref
                          .read(adminUserFilterProvider.notifier)
                          .state = role,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(color: AppColors.error),
                ),
              ),
            ),
            data: (users) {
              if (users.isEmpty) {
                return Center(
                  child: Text(
                    'Tidak ada pengguna pada filter ini.',
                    style: AppTextStyles.caption,
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xxl,
                ),
                itemCount: users.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) => _UserTile(user: users[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outline),
      ),
      child: ListTile(
        onTap: () => _showDetail(context, ref),
        leading: CircleAvatar(
          backgroundColor:
              user.isActive ? AppColors.primaryLight : AppColors.errorLight,
          child: Text(
            user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
            style: AppTextStyles.bodyStrong.copyWith(
              color: user.isActive ? AppColors.primaryDark : AppColors.error,
              fontSize: 15,
            ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                user.name,
                style: AppTextStyles.bodyStrong.copyWith(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!user.isActive) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'NONAKTIF',
                  style: AppTextStyles.base.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(user.email, style: AppTextStyles.caption),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            user.role.label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.name, style: AppTextStyles.headline),
            const SizedBox(height: 2),
            Text(user.email, style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.md),
            _DetailRow(label: 'Peran', value: user.role.label),
            _DetailRow(
              label: 'Status',
              value: user.isActive ? 'Aktif' : 'Ditangguhkan',
            ),
            if (user.createdAt != null)
              _DetailRow(
                label: 'Terdaftar',
                value: Formatters.dateTime(user.createdAt!),
              ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(
                  user.isActive
                      ? Icons.block_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 18,
                ),
                label: Text(
                  user.isActive ? 'Tangguhkan akun' : 'Aktifkan kembali',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      user.isActive ? AppColors.error : AppColors.primary,
                ),
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await _toggleActive(context, ref);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(BuildContext context, WidgetRef ref) async {
    final makeActive = !user.isActive;

    if (!makeActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Tangguhkan Akun'),
          content: Text(
            '${user.name} tidak akan bisa login dan sesinya langsung berakhir. '
            'Pesanan lamanya tetap tersimpan.',
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
              child: const Text('Tangguhkan'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await setUserActive(ref, userId: user.id, isActive: makeActive);
      if (context.mounted) {
        AppFeedback.success(
          context,
          makeActive ? 'Akun diaktifkan kembali.' : 'Akun ditangguhkan.',
        );
      }
    } on Exception catch (e) {
      if (context.mounted) AppFeedback.error(context, '$e');
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
          Text(
            value,
            style: AppTextStyles.bodyStrong.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/ui/app_feedback.dart';
import '../core/validation/validators.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../repositories/auth_repository.dart';
import '../widgets/app_text_field.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_body.dart';

/// P9: `ProfileForm` — HANYA mengurus input & status UI.
///
/// Aturan input ada di `Validators`, request API ada di `ProfileRepository`.
/// Screen ini tidak tahu bagaimana data disimpan.
class ProfileFormScreen extends ConsumerStatefulWidget {
  const ProfileFormScreen({super.key});

  @override
  ConsumerState<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends ConsumerState<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    // Prefill dari sesi berjalan supaya user tidak mengetik ulang.
    final user = ref.read(currentUserProvider);
    final parts = (user?.name ?? '').split(' ');
    _firstName = TextEditingController(text: parts.first);
    _lastName = TextEditingController(
      text: parts.length > 1 ? parts.sublist(1).join(' ') : '',
    );
    _email = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final current = ref.read(currentUserProvider);
    if (current == null) return;

    await ref.read(profileUpdateProvider.notifier).save(
          current: current,
          firstName: _firstName.text,
          lastName: _lastName.text,
          email: _email.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final updateAsync = ref.watch(profileUpdateProvider);
    final isLoading = updateAsync.isLoading;

    ref.listen<AsyncValue<AuthUser?>>(profileUpdateProvider, (previous, next) {
      // P8: setiap aksi memberi umpan balik, termasuk sukses & gagal.
      if (next.hasError) {
        AppFeedback.error(context, next.error.toString());
        return;
      }
      final user = next.valueOrNull;
      if (user == null) return;

      ref.read(authProvider.notifier).replaceUser(user);
      AppFeedback.success(context, 'Profil berhasil diperbarui.');
      Navigator.pop(context);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Kembali',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Edit Profil',
                    style: AppTextStyles.headline
                        .copyWith(color: AppColors.textOnPrimary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ResponsiveBody(
                  maxWidth: 560,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          label: 'Nama Depan',
                          hint: 'William',
                          controller: _firstName,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              Validators.required(v, 'Nama depan'),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          label: 'Nama Belakang',
                          hint: 'She',
                          controller: _lastName,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              Validators.required(v, 'Nama belakang'),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          label: 'Email',
                          hint: 'nama@email.com',
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          validator: Validators.email,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        PrimaryButton(
                          text: isLoading ? 'Menyimpan...' : 'Simpan Perubahan',
                          icon: Icons.save_rounded,
                          isLoading: isLoading,
                          onPressed: isLoading ? null : _save,
                        ),
                      ],
                    ),
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

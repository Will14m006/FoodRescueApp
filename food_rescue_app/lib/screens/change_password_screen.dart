import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/ui/app_feedback.dart';
import '../core/validation/validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_text_field.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_body.dart';

/// Ubah password. Password lama wajib benar — server yang memverifikasi.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).changePassword(
            token: user.token,
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      AppFeedback.success(context, 'Password berhasil diubah.');
      Navigator.pop(context);
    } on Exception catch (e) {
      if (mounted) AppFeedback.error(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md + 2,
                AppSpacing.md + 2,
                AppSpacing.md + 2,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Kembali',
                    onPressed: () => Navigator.pop(context),
                    background: AppColors.surface,
                    foreground: AppColors.textPrimary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text('Ubah Password', style: AppTextStyles.title),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ResponsiveBody(
                  maxWidth: 520,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Masukkan password lama untuk memastikan ini benar-'
                          'benar kamu, lalu pilih password baru.',
                          style: AppTextStyles.body,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        AppTextField(
                          label: 'Password Lama',
                          hint: '••••••••',
                          isPassword: true,
                          prefixIcon: Icons.lock_outline_rounded,
                          controller: _current,
                          validator: (v) =>
                              Validators.required(v, 'Password lama'),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          label: 'Password Baru',
                          hint: 'Minimal 8 karakter',
                          isPassword: true,
                          prefixIcon: Icons.lock_reset_rounded,
                          controller: _next,
                          validator: (v) =>
                              Validators.minLength(v, label: 'Password baru', min: 8),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          label: 'Ulangi Password Baru',
                          hint: '••••••••',
                          isPassword: true,
                          prefixIcon: Icons.lock_reset_rounded,
                          controller: _confirm,
                          validator: (v) {
                            if (v != _next.text) {
                              return 'Konfirmasi password tidak cocok.';
                            }
                            return Validators.required(v, 'Konfirmasi');
                          },
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        PrimaryButton(
                          text: 'Simpan Password',
                          icon: Icons.check_rounded,
                          isLoading: _saving,
                          onPressed: _saving ? null : _submit,
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

import 'package:flutter/material.dart';

/// Input field reusable.
///
/// Mendukung controller, validator, dan keyboard type sehingga bisa dipakai
/// untuk form yang perlu validasi (contoh: form pemesanan).
class AppTextField extends StatelessWidget {
  final String label;
  final bool isPassword;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final TextCapitalization textCapitalization;

  const AppTextField({
    super.key,
    required this.label,
    this.isPassword = false,
    this.controller,
    this.validator,
    this.keyboardType,
    this.onChanged,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      textCapitalization: textCapitalization,
      maxLines: isPassword ? 1 : maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

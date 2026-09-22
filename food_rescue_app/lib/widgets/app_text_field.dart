import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final bool isPassword;

  const AppTextField({super.key, required this.label, this.isPassword = false});

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
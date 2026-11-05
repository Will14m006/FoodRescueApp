import 'package:flutter/material.dart';

/// P8: breakpoint layout adaptif.
///
/// - `compact`  : HP (< 600)
/// - `medium`   : tablet (600 - 900)
/// - `expanded` : desktop (> 900)
abstract class Breakpoints {
  static const double medium = 600;
  static const double expanded = 900;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < medium;

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expanded;
}

/// P8: membatasi lebar konten di layar besar supaya baris teks tidak
/// melebar (nyaman dibaca) dan tetap full-width di HP.
///
/// Dipakai membungkus isi layar (form, list, detail), bukan header gradient
/// yang memang harus selebar layar.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = 720,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

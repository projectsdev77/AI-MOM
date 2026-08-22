import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(onPressed: onPressed, child: Text(label));
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

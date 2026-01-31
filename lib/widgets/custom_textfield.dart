import 'package:flutter/material.dart';
import 'package:shop_app/utils/app_theme.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final bool enabled;
  final int maxLines;
  final String? Function(String?)? validator;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        enabled: enabled,
        maxLines: obscureText ? 1 : maxLines,
        validator: validator,
        style: AppTheme.bodyStyle,
        decoration: AppTheme.inputDecoration(
          label,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: AppTheme.primaryColor)
              : null,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Form alanlarının ortak görünümü.
///
/// Şifre alanlarında [obscurable] verildiğinde göz ikonuyla görünürlük
/// değiştirilebilir.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscurable = false,
    this.autofillHints,
    this.validator,
    this.enabled = true,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  /// Alan bir şifre alanı mı.
  final bool obscurable;

  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final bool enabled;
  final VoidCallback? onSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscurable;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          enabled: widget.enabled,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          validator: widget.validator,
          onFieldSubmitted: (_) => widget.onSubmitted?.call(),
          style: textTheme.bodyLarge,
          cursorColor: AppColors.red,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.inkFaint),
            filled: true,
            fillColor: widget.enabled ? AppColors.white : AppColors.surfaceSoft,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, size: 20, color: AppColors.inkFaint),
            suffixIcon: widget.obscurable
                ? IconButton(
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppColors.inkFaint,
                    ),
                    tooltip: _obscured ? 'Şifreyi göster' : 'Şifreyi gizle',
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            border: _border(AppColors.border),
            enabledBorder: _border(AppColors.border),
            focusedBorder: _border(AppColors.red, width: 1.6),
            errorBorder: _border(AppColors.red),
            focusedErrorBorder: _border(AppColors.red, width: 1.6),
            disabledBorder: _border(AppColors.border),
            errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.red),
          ),
        ),
      ],
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AppRadius.md,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Yükleniyor durumu olan ana buton.
///
/// [isLoading] iken buton devre dışı kalır ve içinde bir ilerleme göstergesi
/// döner; böylece ağ isteği süren akışlarda çift dokunma engellenir.
class AsyncPrimaryButton extends StatelessWidget {
  const AsyncPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.white,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: isLoading
          ? ElevatedButton.styleFrom(
              // Yüklenirken buton "pasif gri" görünmesin.
              disabledBackgroundColor: AppColors.red,
              disabledForegroundColor: AppColors.white,
            )
          : null,
      child: child,
    );
  }
}

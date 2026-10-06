import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Form ve akış hatalarını gösteren şerit.
///
/// Hata rengi olarak lacivert kullanılır: kırmızı markanın ana rengi olduğu
/// için hata vurgusu olarak kullanıldığında ayırt edilemiyor.
class MessageBanner extends StatelessWidget {
  const MessageBanner.error(this.message, {super.key})
      : _background = AppColors.blueSurface,
        _foreground = AppColors.navy,
        _icon = Icons.error_outline_rounded;

  const MessageBanner.success(this.message, {super.key})
      : _background = AppColors.greenSurface,
        _foreground = AppColors.greenDark,
        _icon = Icons.check_circle_outline_rounded;

  const MessageBanner.info(this.message, {super.key})
      : _background = AppColors.surfaceSoft,
        _foreground = AppColors.inkMuted,
        _icon = Icons.info_outline_rounded;

  final String message;
  final Color _background;
  final Color _foreground;
  final IconData _icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: _background, borderRadius: AppRadius.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: 20, color: _foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: _foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

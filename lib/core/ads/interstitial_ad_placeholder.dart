import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Geçiş reklamının yerini tutan geçici tam ekran diyalog.
///
/// Gerçek `InterstitialAd` bağlanınca bu dosya silinecek; şimdilik reklam
/// tetikleyicisinin doğru soruda çalıştığını gözle doğrulamayı sağlıyor.
Future<void> showInterstitialAdPlaceholder(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.ink.withValues(alpha: 0.6),
    builder: (context) => const _InterstitialPlaceholderDialog(),
  );
}

class _InterstitialPlaceholderDialog extends StatelessWidget {
  const _InterstitialPlaceholderDialog();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.xxl),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.redSurface,
                borderRadius: AppRadius.pill,
              ),
              child: Text(
                'GEÇİŞ REKLAMI',
                style: textTheme.labelSmall?.copyWith(color: AppColors.redDark),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Icon(Icons.ondemand_video_rounded,
                size: 48, color: AppColors.inkFaint),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Interstitial yer tutucusu',
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Her 5 soruda bir bu noktada geçiş reklamı gösterilecek.',
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Devam et'),
            ),
          ],
        ),
      ),
    );
  }
}

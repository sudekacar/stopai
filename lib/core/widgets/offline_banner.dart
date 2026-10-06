import 'package:flutter/material.dart';

import '../network/network_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Çevrimdışıyken ekranın üstünde duran şerit.
class OfflineModeBanner extends StatelessWidget {
  const OfflineModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navy,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.white,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Çevrimdışı Mod',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      'Kayıtlı testlerin ve profilin kullanılabilir.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.white.withValues(alpha: 0.82),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [NetworkStatus] çevrimdışıyken çocuğun üstüne banner ekler.
class OfflineBannerHost extends StatelessWidget {
  const OfflineBannerHost({
    super.key,
    required this.network,
    required this.child,
  });

  final NetworkStatus network;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: network,
      builder: (context, _) {
        return Column(
          children: [
            if (network.isOffline) const OfflineModeBanner(),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

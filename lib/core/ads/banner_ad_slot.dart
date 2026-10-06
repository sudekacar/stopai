import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'ad_config.dart';

/// Ekranın en altında sabit duran banner reklam yuvası.
///
/// Gerçek reklam widget'ı (`AdWidget`) gelene kadar yerini tutan bir yer
/// tutucu gösterir. Yükseklik [AdConfig.bannerHeight] ile sabit olduğu için
/// reklam yüklendiğinde yerleşim kaymaz. Kullanıcı paket satın aldığında
/// `AdManager.adsEnabled` false olur ve yuva tamamen kaybolur.
class BannerAdSlot extends StatelessWidget {
  const BannerAdSlot({super.key});

  @override
  Widget build(BuildContext context) {
    final ads = AppScope.of(context).ads;

    return ListenableBuilder(
      listenable: ads,
      builder: (context, _) {
        if (!ads.adsEnabled) return const SizedBox.shrink();

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceSoft,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: AdConfig.bannerHeight,
              width: double.infinity,
              // TODO(ads): Burayı yüklenen banner için `AdWidget(ad: _bannerAd)`
              // ile değiştir; yükleme bitene kadar yer tutucu görünsün.
              child: const _BannerPlaceholder(),
            ),
          ),
        );
      },
    );
  }
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: AppRadius.sm,
              border: Border.all(color: AppColors.border),
            ),
            child: Text('REKLAM', style: Theme.of(context).textTheme.labelSmall),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Banner alanı ayrıldı',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.inkFaint),
          ),
        ],
      ),
    );
  }
}

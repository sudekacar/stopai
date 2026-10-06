import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_primary_button.dart';
import '../../../core/widgets/message_banner.dart';
import '../domain/purchase_product.dart';
import 'entitlement_controller.dart';

/// Paywall'ı açar. Satın alma yapıldıysa `true` döner.
Future<bool> showPaywall(BuildContext context, {String? reason}) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(builder: (_) => PaywallScreen(reason: reason)),
  );
  return result ?? false;
}

/// Kilitli bir alana dokunulduğunda açılan fırsat ekranı.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, this.reason});

  /// Kullanıcının hangi kilitten geldiğini anlatan kısa metin.
  final String? reason;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppScope.of(context).entitlement.refreshOfferings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = AppScope.of(context).entitlement;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fırsat'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Kapat',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: ListenableBuilder(
        listenable: entitlement,
        builder: (context, _) {
          if (entitlement.entitlement.hasAnyPurchase) {
            return _PurchaseSuccessView(
              planLabel: entitlement.entitlement.planLabel,
              warning: entitlement.errorMessage,
            );
          }
          return _OfferView(controller: entitlement, reason: widget.reason);
        },
      ),
    );
  }
}

class _OfferView extends StatelessWidget {
  const _OfferView({required this.controller, this.reason});

  final EntitlementController controller;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.sm,
        AppSpacing.screenGutter,
        AppSpacing.xxxl,
      ),
      children: [
        if (reason != null) ...[
          MessageBanner.info(reason!),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Kullanıcının istediği fırsat metni birebir burada.
        Text(
          '🚨 FIRSAT!!',
          style: textTheme.displaySmall?.copyWith(color: AppColors.red),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        const _OfferBullet(
          'Testlerin geri kalanını ömür boyu görmek için sadece 99 TL öde!',
        ),
        const SizedBox(height: AppSpacing.sm),
        const _OfferBullet(
          'AI ile görselli ve sesli çalışmak için sadece 299 TL!',
        ),
        const SizedBox(height: AppSpacing.xxl),

        for (final product in controller.products)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: _ProductCard(
              product: product,
              isPurchasing: controller.purchasingProduct == product.id,
              isAnyPurchasing: controller.isPurchasing,
              onPurchase: () => _PurchaseActions.buy(context, controller, product.id),
            ),
          ),

        if (controller.errorMessage != null) ...[
          MessageBanner.error(controller.errorMessage!),
          const SizedBox(height: AppSpacing.lg),
        ],

        TextButton(
          onPressed: controller.isPurchasing
              ? null
              : () => _PurchaseActions.restore(context, controller),
          child: const Text('Satın alımlarımı geri yükle'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Ödemeler tek seferliktir, abonelik değildir. Satın alma sonrası tüm '
          'testlerin kilidi açılır ve reklamlar kaldırılır.',
          style: textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _OfferBullet extends StatelessWidget {
  const _OfferBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 7),
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppColors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.isPurchasing,
    required this.isAnyPurchasing,
    required this.onPurchase,
  });

  final PurchaseProduct product;
  final bool isPurchasing;
  final bool isAnyPurchasing;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final highlighted = product.isHighlighted;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.redSurface : AppColors.white,
        borderRadius: AppRadius.lg,
        border: Border.all(
          color: highlighted ? AppColors.red : AppColors.border,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(product.title, style: textTheme.titleLarge)),
              if (highlighted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.red,
                    borderRadius: AppRadius.pill,
                  ),
                  child: Text(
                    'EN KAPSAMLI',
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(product.headline, style: textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          Text(
            product.priceLabel,
            style: textTheme.displaySmall?.copyWith(color: AppColors.red),
          ),
          Text('tek seferlik ödeme', style: textTheme.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          for (final benefit in product.benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(benefit, style: textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          AsyncPrimaryButton(
            label: '${product.priceLabel} - Satın Al',
            isLoading: isPurchasing,
            onPressed: isAnyPurchasing ? null : onPurchase,
          ),
        ],
      ),
    );
  }
}

class _PurchaseSuccessView extends StatelessWidget {
  const _PurchaseSuccessView({required this.planLabel, this.warning});

  final String planLabel;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Center(
            child: Icon(
              Icons.verified_rounded,
              size: 72,
              color: AppColors.green,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Satın alma tamamlandı',
            style: textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            planLabel,
            style: textTheme.titleMedium?.copyWith(color: AppColors.green),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Tüm testlerin kilidi açıldı ve reklamlar kaldırıldı.',
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (warning != null) ...[
            const SizedBox(height: AppSpacing.lg),
            MessageBanner.info(warning!),
          ],
          const Spacer(),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );
  }
}

/// Satın alma sonrası Snackbar ve Sandbox/Test dialog.
abstract final class _PurchaseActions {
  static Future<void> buy(
    BuildContext context,
    EntitlementController controller,
    ProductId productId,
  ) async {
    final success = await controller.purchase(productId);
    if (!context.mounted) return;
    await present(context, controller, success: success);
  }

  static Future<void> restore(
    BuildContext context,
    EntitlementController controller,
  ) async {
    await controller.restore();
    if (!context.mounted) return;
    await present(
      context,
      controller,
      success: controller.entitlement.hasAnyPurchase,
    );
  }

  static Future<void> present(
    BuildContext context,
    EntitlementController controller, {
    required bool success,
  }) async {
    final error = controller.errorMessage;
    final messenger = ScaffoldMessenger.of(context);

    if (success) {
      // Başarı ekranı kilitleri zaten açtı; snackbar "Devam Et"i örtmesin.
      return;
    }

    if (error == null || error.isEmpty) return;

    messenger.showSnackBar(
      SnackBar(content: Text(error), backgroundColor: AppColors.navy),
    );

    if (!controller.lastFailureIsSandbox) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Test / Sandbox hatası'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}

import '../../../core/services/purchase_service.dart';
import '../domain/purchase_product.dart';
import '../domain/subscription_status.dart';

/// Mağaza satın alma akışı.
///
/// Gerçek cihazda [PurchaseService] (RevenueCat) çağrılır; testlerde servis
/// bağlanmadığı için kısa bir simülasyon çalışır — ya da [FakePurchaseService]
/// enjekte edilir. Hakkın kendisi sunucudaki `users.subscription_status`.
class PurchaseRepository {
  const PurchaseRepository({this.purchaseService});

  final PurchaseService? purchaseService;

  /// Paywall kartlarının varsayılan metinleri.
  static List<PurchaseProduct> get catalog => PurchaseCatalog.products;

  /// Paywall'da gösterilecek paketler (katalog kopyası).
  List<PurchaseProduct> fetchOfferings() => PurchaseCatalog.products;

  /// Mağazadaki güncel fiyatları katalog kartlarının üzerine yazar.
  Future<List<PurchaseProduct>> loadStoreOfferings() async {
    final service = purchaseService;
    if (service == null || !service.isReady) return PurchaseCatalog.products;

    try {
      return await service.loadOfferings();
    } on PurchaseException {
      return PurchaseCatalog.products;
    }
  }

  /// Mağaza ödemesini yürütür ve kazanılan paket durumunu döner.
  Future<SubscriptionStatus> purchaseFromStore(ProductId productId) async {
    final service = purchaseService;
    if (service == null) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      return productId.grantedStatus;
    }

    final result = await service.purchaseProduct(productId);
    if (result.cancelled) {
      throw const PurchaseException.cancelled();
    }
    if (result.status == SubscriptionStatus.free) {
      throw const PurchaseException(
        'Satın alma alındı ama paket hakkı henüz aktif görünmüyor. '
        'Satın alımları geri yüklemeyi deneyin.',
      );
    }
    return result.status;
  }

  /// Mağazadaki geçmiş satın alımları okur.
  Future<SubscriptionStatus> restorePurchases() async {
    final service = purchaseService;
    if (service == null) return SubscriptionStatus.free;

    final result = await service.restorePurchases();
    if (result.cancelled) return SubscriptionStatus.free;
    return result.status;
  }
}

import 'subscription_status.dart';

/// Satışa açık paketler. RevenueCat'teki paket tanımlayıcılarına karşılık gelir.
enum ProductId {
  lifetimeTests('com.stopkoc.lifetime_tests', SubscriptionStatus.lifetimeTests),
  aiPro('com.stopkoc.ai_pro', SubscriptionStatus.aiPro);

  const ProductId(this.storeIdentifier, this.grantedStatus);

  /// Mağazadaki (App Store / Play) ürün kimliği.
  final String storeIdentifier;

  /// Satın alındığında kullanıcının geçtiği paket durumu.
  final SubscriptionStatus grantedStatus;
}

/// Paywall'da gösterilen tek bir paket.
class PurchaseProduct {
  const PurchaseProduct({
    required this.id,
    required this.title,
    required this.priceLabel,
    required this.headline,
    required this.benefits,
    this.isHighlighted = false,
  });

  final ProductId id;
  final String title;

  /// Mağazadan gelen yerelleştirilmiş fiyat metni.
  final String priceLabel;

  /// Kartın üstündeki tek satırlık vaat.
  final String headline;

  final List<String> benefits;

  /// Kartın kırmızı çerçeveyle öne çıkarılması.
  final bool isHighlighted;
}

/// Paywall kartlarının varsayılan metinleri. Mağaza fiyatı gelince
/// [PurchaseService.loadOfferings] bunun üzerine yazar.
abstract final class PurchaseCatalog {
  static const List<PurchaseProduct> products = [
    PurchaseProduct(
      id: ProductId.lifetimeTests,
      title: 'Ömür Boyu Test Paketi',
      priceLabel: '99 TL',
      headline: 'Testlerin geri kalanını ömür boyu görmek için sadece '
          '99 TL öde!',
      benefits: [
        '2-20 arası tüm testlerin kilidi kalıcı olarak açılır',
        'Tek seferlik ödeme, abonelik yok',
        'Reklamlar tamamen kaldırılır',
      ],
    ),
    PurchaseProduct(
      id: ProductId.aiPro,
      title: 'AI Pro Paket',
      priceLabel: '299 TL',
      headline: 'AI ile görselli ve sesli çalışmak için sadece 299 TL!',
      benefits: [
        'Araç parçası fotoğraflarını yükleyip AI koça sor',
        'Sesli anlatım ile konu tekrarı',
        'Ömür boyu test paketinin tamamı dahil',
        'Reklamlar tamamen kaldırılır',
      ],
      isHighlighted: true,
    ),
  ];
}

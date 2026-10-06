import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../features/purchase/domain/purchase_product.dart';
import '../../features/purchase/domain/subscription_status.dart';
import '../purchases/purchase_config.dart';

/// Mağaza hatasının türü; sandboxed TestFlight / Play iç test hesapları
/// [PurchaseFailureKind.sandbox] olarak ayrılır.
enum PurchaseFailureKind {
  cancelled,
  network,
  sandbox,
  store,
  notAvailable,
  unknown,
}

/// Mağaza / RevenueCat hatalarını arayüzün konuştuğu dile çevirir.
class PurchaseException implements Exception {
  const PurchaseException(
    this.message, {
    this.cancelled = false,
    this.kind = PurchaseFailureKind.unknown,
  });

  const PurchaseException.cancelled()
      : message = '',
        cancelled = true,
        kind = PurchaseFailureKind.cancelled;

  final String message;
  final bool cancelled;
  final PurchaseFailureKind kind;

  bool get isSandbox => kind == PurchaseFailureKind.sandbox;

  @override
  String toString() =>
      cancelled ? 'PurchaseException.cancelled' : 'PurchaseException($message)';
}

/// Satın alma veya geri yükleme sonucu.
class StorePurchaseResult {
  const StorePurchaseResult({
    required this.status,
    this.cancelled = false,
    this.hasProAccess = false,
    this.hasLifetimeTests = false,
  });

  const StorePurchaseResult.cancelled()
      : status = SubscriptionStatus.free,
        cancelled = true,
        hasProAccess = false,
        hasLifetimeTests = false;

  const StorePurchaseResult.empty()
      : status = SubscriptionStatus.free,
        cancelled = false,
        hasProAccess = false,
        hasLifetimeTests = false;

  factory StorePurchaseResult.fromStatus(SubscriptionStatus status) {
    return StorePurchaseResult(
      status: status,
      hasProAccess: status == SubscriptionStatus.aiPro,
      hasLifetimeTests: status != SubscriptionStatus.free,
    );
  }

  final SubscriptionStatus status;
  final bool cancelled;
  final bool hasProAccess;
  final bool hasLifetimeTests;
}

/// Mağaza satın alma sözleşmesi.
///
/// Gerçek uygulama [RevenueCatPurchaseService] kullanır; testler
/// [FakePurchaseService] bağlar. Native SDK buradan çağrılmaz, bu yüzden
/// unit testler platform kanalına ihtiyaç duymaz.
abstract class PurchaseService {
  const PurchaseService();

  factory PurchaseService.revenueCat() = RevenueCatPurchaseService;

  /// SDK yapılandırıldı ve mağaza çağrıları yapılabilir mi.
  bool get isReady;

  Future<void> init();

  /// Paywall kartları (mağaza fiyatı varsa üzerine yazılmış katalog).
  Future<List<PurchaseProduct>> loadOfferings();

  /// Seçilen mağaza ürününü satın alır.
  Future<StorePurchaseResult> purchaseProduct(ProductId productId);

  Future<StorePurchaseResult> restorePurchases();

  /// Uygulama kullanıcısını RevenueCat app user id ile eşler.
  Future<StorePurchaseResult> loginUser(String userId);

  Future<void> logOutUser();

  /// Mağaza müşteri bilgisi değişince (başarılı IAP, restore) çağrılır.
  void addCustomerInfoListener(
    void Function(StorePurchaseResult result) listener,
  ) {}

  void removeCustomerInfoListener(
    void Function(StorePurchaseResult result) listener,
  ) {}

  /// Entitlement / ürün kimliklerini backend `subscription_status` değerine çevirir.
  ///
  /// RevenueCat panel:
  /// - `lifetime_tests` → [SubscriptionStatus.lifetimeTests]
  /// - `pro_access` veya `ai_pro` → [SubscriptionStatus.aiPro]
  /// Ürün kimliği (`com.stopkoc.*`) entitlement tanımlı olmasa da yedek olarak okunur.
  static SubscriptionStatus statusFrom({
    required Iterable<String> activeEntitlements,
    required Iterable<String> purchasedProductIds,
  }) {
    final entitlements =
        activeEntitlements.map((id) => id.toLowerCase()).toSet();
    final products =
        purchasedProductIds.map((id) => id.toLowerCase()).toSet();

    final hasAi = entitlements.contains(PurchaseConfig.proAccessEntitlement) ||
        entitlements.contains(PurchaseConfig.aiProEntitlementAlias) ||
        products.contains(PurchaseConfig.aiProProductId.toLowerCase());
    if (hasAi) return SubscriptionStatus.aiPro;

    final hasTests =
        entitlements.contains(PurchaseConfig.lifetimeTestsEntitlement) ||
            entitlements.contains('tests_access') ||
            products.contains(
              PurchaseConfig.lifetimeTestsProductId.toLowerCase(),
            );
    if (hasTests) return SubscriptionStatus.lifetimeTests;

    return SubscriptionStatus.free;
  }

  static StorePurchaseResult resultFromCustomerInfo(CustomerInfo info) {
    final status = statusFrom(
      activeEntitlements: info.entitlements.active.keys,
      purchasedProductIds: [
        ...info.allPurchasedProductIdentifiers,
        ...info.activeSubscriptions,
        for (final entitlement in info.entitlements.active.values)
          entitlement.productIdentifier,
      ],
    );
    return StorePurchaseResult.fromStatus(status);
  }
}

/// RevenueCat SDK sarmalayıcısı.
class RevenueCatPurchaseService extends PurchaseService {
  RevenueCatPurchaseService();

  Offerings? _offerings;
  bool _ready = false;
  bool _listening = false;
  final List<void Function(StorePurchaseResult result)> _listeners = [];

  @override
  bool get isReady => _ready;

  /// Son çekilen teklifler; [fetchOfferings] çağrılmadan `null`.
  Offerings? get cachedOfferings => _offerings;

  /// [PurchaseConfig.platformApiKey] ile SDK'yı başlatır.
  @override
  Future<void> init() async {
    if (_ready) return;

    if (!PurchaseConfig.isStoreSupported) {
      if (kDebugMode) {
        debugPrint(
          '[PurchaseService] Mağaza bu platformda yok '
          '(${defaultTargetPlatform.name}).',
        );
      }
      return;
    }

    final apiKey = PurchaseConfig.platformApiKey;
    if (apiKey.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[PurchaseService] API anahtarı yok (kaynak: '
          '${PurchaseConfig.apiKeySource.name}). '
          '--dart-define=REVENUECAT_APPLE_API_KEY=appl_... veya '
          'REVENUECAT_GOOGLE_API_KEY=goog_... verin.',
        );
      }
      return;
    }

    try {
      await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(apiKey));
      _attachCustomerInfoListener();
      _ready = true;
      if (kDebugMode) {
        debugPrint(
          '[PurchaseService] RevenueCat başlatıldı '
          '(${PurchaseConfig.apiKeySource.name}).',
        );
      }
    } on MissingPluginException {
      if (kDebugMode) {
        debugPrint('[PurchaseService] Eklenti bu ortamda yok, atlanıyor.');
      }
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('[PurchaseService] init başarısız: ${error.message}');
      }
    }
  }

  /// Aktif teklifleri (Offerings) mağazadan çeker.
  Future<Offerings> fetchOfferings() async {
    _ensureReady();
    try {
      _offerings = await Purchases.getOfferings();
      return _offerings!;
    } on PlatformException catch (error) {
      throw _mapPlatform(error);
    }
  }

  @override
  Future<List<PurchaseProduct>> loadOfferings() async {
    try {
      final offerings = await fetchOfferings();
      return [
        for (final product in PurchaseCatalog.products)
          _withStorePrice(product, offerings),
      ];
    } on PurchaseException {
      return PurchaseCatalog.products;
    }
  }

  /// Seçilen paketi satın alır; ardından `pro_access` / `lifetime_tests`
  /// haklarının aktif olup olmadığına bakar.
  Future<StorePurchaseResult> purchasePackage(Package package) async {
    _ensureReady();
    try {
      final purchase = await Purchases.purchase(PurchaseParams.package(package));
      return PurchaseService.resultFromCustomerInfo(purchase.customerInfo);
    } on PlatformException catch (error) {
      final code = _errorCode(error);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return const StorePurchaseResult.cancelled();
      }
      if (code == PurchasesErrorCode.productAlreadyPurchasedError) {
        return restorePurchases();
      }
      throw _mapPlatform(error);
    }
  }

  @override
  Future<StorePurchaseResult> restorePurchases() async {
    _ensureReady();
    try {
      final info = await Purchases.restorePurchases();
      return PurchaseService.resultFromCustomerInfo(info);
    } on PlatformException catch (error) {
      throw _mapPlatform(error);
    }
  }

  @override
  Future<StorePurchaseResult> loginUser(String userId) async {
    if (!_ready) return const StorePurchaseResult.empty();
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return const StorePurchaseResult.empty();

    try {
      final result = await Purchases.logIn(trimmed);
      return PurchaseService.resultFromCustomerInfo(result.customerInfo);
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('[PurchaseService] loginUser: ${error.message}');
      }
      throw _mapPlatform(error);
    }
  }

  @override
  Future<void> logOutUser() async {
    if (!_ready) return;
    try {
      await Purchases.logOut();
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('[PurchaseService] logOutUser: ${error.message}');
      }
    }
  }

  @override
  void addCustomerInfoListener(
    void Function(StorePurchaseResult result) listener,
  ) {
    _listeners.add(listener);
  }

  @override
  void removeCustomerInfoListener(
    void Function(StorePurchaseResult result) listener,
  ) {
    _listeners.remove(listener);
  }

  void _attachCustomerInfoListener() {
    if (_listening) return;
    _listening = true;
    Purchases.addCustomerInfoUpdateListener((info) {
      final result = PurchaseService.resultFromCustomerInfo(info);
      for (final listener in List.of(_listeners)) {
        listener(result);
      }
    });
  }

  Package? packageFor(ProductId productId) {
    final offerings = _offerings;
    if (offerings == null) return null;
    return findPackage(offerings, productId);
  }

  @override
  Future<StorePurchaseResult> purchaseProduct(ProductId productId) async {
    var package = packageFor(productId);
    if (package == null) {
      final offerings = await fetchOfferings();
      package = findPackage(offerings, productId);
    }
    if (package == null) {
      throw const PurchaseException(
        'Bu paket mağazada şu an satışta değil. Biraz sonra tekrar deneyin.',
      );
    }
    return purchasePackage(package);
  }

  static Package? findPackage(Offerings offerings, ProductId productId) {
    final seen = <Package>{};
    final packages = <Package>[
      ...?offerings.current?.availablePackages,
      for (final offering in offerings.all.values) ...offering.availablePackages,
    ];

    for (final package in packages) {
      if (!seen.add(package)) continue;
      if (package.storeProduct.identifier == productId.storeIdentifier) {
        return package;
      }
    }
    return null;
  }

  static PurchaseProduct _withStorePrice(
    PurchaseProduct product,
    Offerings offerings,
  ) {
    final package = findPackage(offerings, product.id);
    if (package == null) return product;

    final price = package.storeProduct.priceString.trim();
    if (price.isEmpty) return product;

    return PurchaseProduct(
      id: product.id,
      title: product.title,
      priceLabel: price,
      headline: product.headline,
      benefits: product.benefits,
      isHighlighted: product.isHighlighted,
    );
  }

  void _ensureReady() {
    if (_ready) return;
    if (!PurchaseConfig.isStoreSupported) {
      throw const PurchaseException(
        'Satın alma bu cihazda kullanılamıyor. iPhone veya Android ile deneyin.',
      );
    }
    throw const PurchaseException(
      'Mağaza henüz hazır değil. RevenueCat API anahtarını kontrol edin.',
    );
  }

  static PurchasesErrorCode? _errorCode(PlatformException error) {
    try {
      return PurchasesErrorHelper.getErrorCode(error);
    } on Object {
      return null;
    }
  }

  static PurchaseException _mapPlatform(PlatformException error) {
    final code = _errorCode(error);
    final fallback = (error.message != null && error.message!.trim().isNotEmpty)
        ? error.message!.trim()
        : 'Satın alma tamamlanamadı. Lütfen tekrar deneyin.';

    return switch (code) {
      PurchasesErrorCode.purchaseCancelledError =>
        const PurchaseException.cancelled(),
      PurchasesErrorCode.networkError ||
      PurchasesErrorCode.offlineConnectionError => const PurchaseException(
          'Mağazaya ulaşılamadı. İnternet bağlantınızı kontrol edin.',
          kind: PurchaseFailureKind.network,
        ),
      PurchasesErrorCode.purchaseNotAllowedError => const PurchaseException(
          'Bu cihazda satın alma yapılamıyor. Test için Sandbox / lisanslı '
          'test hesabı kullandığınızdan emin olun.',
          kind: PurchaseFailureKind.sandbox,
        ),
      PurchasesErrorCode.productNotAvailableForPurchaseError =>
        const PurchaseException(
          'Bu paket mağazada şu an satışta değil.',
          kind: PurchaseFailureKind.notAvailable,
        ),
      PurchasesErrorCode.storeProblemError => const PurchaseException(
          'Mağaza yanıt vermedi (Sandbox/Test). TestFlight veya Play iç test '
          'hesabıyla tekrar deneyin.',
          kind: PurchaseFailureKind.sandbox,
        ),
      PurchasesErrorCode.configurationError => const PurchaseException(
          'Mağaza yapılandırması eksik. RevenueCat ürün kimliklerini ve '
          'API anahtarını kontrol edin.',
          kind: PurchaseFailureKind.sandbox,
        ),
      PurchasesErrorCode.unexpectedBackendResponseError ||
      PurchasesErrorCode.invalidReceiptError ||
      PurchasesErrorCode.receiptAlreadyInUseError =>
        const PurchaseException(
          'Test (Sandbox) makbuzu doğrulanamadı. Sandbox Apple kimliği veya '
          'Play lisans test hesabıyla giriş yapıp tekrar deneyin.',
          kind: PurchaseFailureKind.sandbox,
        ),
      PurchasesErrorCode.productAlreadyPurchasedError => const PurchaseException(
          'Bu paket zaten hesabınızda. Satın alımları geri yüklemeyi deneyin.',
          kind: PurchaseFailureKind.store,
        ),
      _ => PurchaseException(fallback, kind: PurchaseFailureKind.store),
    };
  }
}

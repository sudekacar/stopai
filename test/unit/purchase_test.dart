import 'package:flutter_test/flutter_test.dart';
import 'package:stop_ai_ehliyet_kocu/core/ads/ad_manager.dart';
import 'package:stop_ai_ehliyet_kocu/core/purchases/purchase_config.dart';
import 'package:stop_ai_ehliyet_kocu/core/services/purchase_service.dart';
import 'package:stop_ai_ehliyet_kocu/core/storage/key_value_store.dart';
import 'package:stop_ai_ehliyet_kocu/core/storage/token_store.dart';
import 'package:stop_ai_ehliyet_kocu/features/auth/data/auth_api.dart';
import 'package:stop_ai_ehliyet_kocu/features/auth/data/auth_repository.dart';
import 'package:stop_ai_ehliyet_kocu/features/auth/presentation/auth_controller.dart';
import 'package:stop_ai_ehliyet_kocu/features/purchase/data/purchase_repository.dart';
import 'package:stop_ai_ehliyet_kocu/features/purchase/domain/entitlement.dart';
import 'package:stop_ai_ehliyet_kocu/features/purchase/domain/purchase_product.dart';
import 'package:stop_ai_ehliyet_kocu/features/purchase/domain/subscription_status.dart';
import 'package:stop_ai_ehliyet_kocu/features/purchase/presentation/entitlement_controller.dart';

import '../helpers/fake_backend.dart';
import '../helpers/fake_purchase_service.dart';
import '../helpers/pump_app.dart';

void main() {
  group('SubscriptionStatus', () {
    test('sunucu değerleri doğru eşlenir', () {
      expect(SubscriptionStatus.fromApi('free'), SubscriptionStatus.free);
      expect(
        SubscriptionStatus.fromApi('lifetime_tests'),
        SubscriptionStatus.lifetimeTests,
      );
      expect(SubscriptionStatus.fromApi('ai_pro'), SubscriptionStatus.aiPro);
    });

    test('bilinmeyen değer en kısıtlı duruma düşer', () {
      // Sunucu yeni bir paket eklerse eski istemci kilitleri açmaz.
      expect(SubscriptionStatus.fromApi('altin_paket'), SubscriptionStatus.free);
      expect(SubscriptionStatus.fromApi(null), SubscriptionStatus.free);
    });

    test('daha kapsamlı paket birleşimde kazanır', () {
      expect(
        SubscriptionStatus.free.merge(SubscriptionStatus.lifetimeTests),
        SubscriptionStatus.lifetimeTests,
      );
      expect(
        SubscriptionStatus.aiPro.merge(SubscriptionStatus.lifetimeTests),
        SubscriptionStatus.aiPro,
      );
    });
  });

  group('Entitlement', () {
    test('ücretsiz kullanıcıda her şey kilitli', () {
      const entitlement = Entitlement.none;

      expect(entitlement.allTestsUnlocked, isFalse);
      expect(entitlement.aiUnlocked, isFalse);
      expect(entitlement.adsRemoved, isFalse);
      expect(entitlement.planLabel, 'Ücretsiz Kullanıcı');
    });

    test('99 TL paketi testleri açar, AI kilitli kalır', () {
      final entitlement =
          Entitlement.fromStatus(SubscriptionStatus.lifetimeTests);

      expect(entitlement.allTestsUnlocked, isTrue);
      expect(entitlement.aiUnlocked, isFalse);
      expect(entitlement.adsRemoved, isTrue);
      expect(entitlement.planLabel, 'Ömür Boyu Test Paketi Aktif');
    });

    test('AI Pro paketi hem AI hem testleri açar', () {
      final entitlement = Entitlement.fromApi('ai_pro');

      expect(entitlement.allTestsUnlocked, isTrue);
      expect(entitlement.aiUnlocked, isTrue);
      expect(entitlement.planLabel, 'AI Pro Paket Aktif');
    });
  });

  group('PurchaseRepository', () {
    const repository = PurchaseRepository();

    test('paywall iki paket sunar: 99 TL ve 299 TL', () {
      final products = repository.fetchOfferings();

      expect(products, hasLength(2));
      expect(products.map((p) => p.priceLabel), ['99 TL', '299 TL']);
      expect(
        products.first.headline,
        'Testlerin geri kalanını ömür boyu görmek için sadece 99 TL öde!',
      );
      expect(
        products.last.headline,
        'AI ile görselli ve sesli çalışmak için sadece 299 TL!',
      );
    });

    test('her ürün kazandırdığı paket durumunu bilir', () {
      expect(
        ProductId.lifetimeTests.grantedStatus,
        SubscriptionStatus.lifetimeTests,
      );
      expect(ProductId.aiPro.grantedStatus, SubscriptionStatus.aiPro);
      expect(
        ProductId.lifetimeTests.storeIdentifier,
        'com.stopkoc.lifetime_tests',
      );
      expect(ProductId.aiPro.storeIdentifier, 'com.stopkoc.ai_pro');
    });
  });

  group('PurchaseService.statusFrom', () {
    test('pro_access entitlement AI Pro haklarını açar', () {
      final status = PurchaseService.statusFrom(
        activeEntitlements: ['pro_access'],
        purchasedProductIds: const [],
      );
      expect(status, SubscriptionStatus.aiPro);
    });

    test('mağaza ürün kimliği entitlement olmasa da tanınır', () {
      expect(
        PurchaseService.statusFrom(
          activeEntitlements: const [],
          purchasedProductIds: ['com.stopkoc.lifetime_tests'],
        ),
        SubscriptionStatus.lifetimeTests,
      );
      expect(
        PurchaseService.statusFrom(
          activeEntitlements: const [],
          purchasedProductIds: ['com.stopkoc.ai_pro'],
        ),
        SubscriptionStatus.aiPro,
      );
    });

    test('hak yoksa ücretsiz kalır', () {
      expect(
        PurchaseService.statusFrom(
          activeEntitlements: const [],
          purchasedProductIds: const [],
        ),
        SubscriptionStatus.free,
      );
    });

    test('lifetime_tests entitlement test paketini açar', () {
      expect(
        PurchaseService.statusFrom(
          activeEntitlements: ['lifetime_tests'],
          purchasedProductIds: const [],
        ),
        SubscriptionStatus.lifetimeTests,
      );
    });

    test('ai_pro alias de AI Pro olarak okunur', () {
      expect(
        PurchaseService.statusFrom(
          activeEntitlements: ['AI_PRO'],
          purchasedProductIds: const [],
        ),
        SubscriptionStatus.aiPro,
      );
    });
  });

  group('EntitlementController', () {
    late FakeBackend backend;
    late AuthController auth;
    late EntitlementController controller;

    setUp(() async {
      backend = FakeBackend();
      final tokenStore = InMemoryTokenStore();
      auth = AuthController(
        AuthRepository(
          AuthApi(createTestApiService(backend, tokenStore: tokenStore)),
          tokenStore,
          InMemoryKeyValueStore(),
        ),
      );
      controller = EntitlementController(auth);

      addTearDown(controller.dispose);
      addTearDown(auth.dispose);

      await auth.bootstrap();
    });

    Future<void> signIn() async {
      await auth.register(
        email: testEmail,
        password: testPassword,
        displayName: testName,
      );
    }

    test('giriş yapılmadan hiçbir hak yok', () {
      expect(controller.entitlement, Entitlement.none);
      expect(controller.allTestsUnlocked, isFalse);
    });

    test('satın alma sunucuya yazılır ve kilitler açılır', () async {
      await signIn();
      expect(controller.allTestsUnlocked, isFalse);

      final success = await controller.purchase(ProductId.lifetimeTests);

      expect(success, isTrue);
      expect(controller.allTestsUnlocked, isTrue);
      expect(controller.aiUnlocked, isFalse);
      expect(controller.isPurchasing, isFalse);
      expect(backend.subscriptionOf(testEmail), 'lifetime_tests');
    });

    test('AI Pro satın alımı AI sekmesini açar', () async {
      await signIn();

      await controller.purchase(ProductId.aiPro);

      expect(controller.aiUnlocked, isTrue);
      expect(controller.allTestsUnlocked, isTrue);
      expect(backend.subscriptionOf(testEmail), 'ai_pro');
    });

    test('satın alma kaydedilemezse kilitler yerelde açılır', () async {
      await signIn();
      backend.offline = true;

      final success = await controller.purchase(ProductId.lifetimeTests);

      expect(success, isTrue);
      expect(controller.allTestsUnlocked, isTrue);
      expect(controller.errorMessage, contains('Paket açıldı'));
    });

    test('paket durumu sunucudan geri yüklenebilir', () async {
      await signIn();
      await controller.purchase(ProductId.aiPro);

      // Aynı hesap başka bir cihazda açılmış gibi: yerel durum sıfır.
      await auth.logout();
      expect(controller.entitlement, Entitlement.none);

      await auth.login(email: testEmail, password: testPassword);
      await controller.restore();

      expect(controller.aiUnlocked, isTrue);
    });

    test('oturum kapanınca haklar sıfırlanır', () async {
      await signIn();
      await controller.purchase(ProductId.aiPro);

      await auth.logout();

      expect(controller.entitlement, Entitlement.none);
    });

    test('reklamlar satın almaya göre kapanır', () async {
      final ads = AdManager();
      addTearDown(ads.dispose);
      // AppServices'in kurduğu bağın aynısı.
      controller.addListener(() => ads.setAdsEnabled(!controller.adsRemoved));

      await signIn();
      expect(ads.adsEnabled, isTrue);

      await controller.purchase(ProductId.lifetimeTests);
      expect(ads.adsEnabled, isFalse);
    });
  });

  group('EntitlementController + FakePurchaseService', () {
    late FakeBackend backend;
    late AuthController auth;
    late FakePurchaseService purchases;
    late EntitlementController controller;

    setUp(() async {
      backend = FakeBackend();
      final tokenStore = InMemoryTokenStore();
      auth = AuthController(
        AuthRepository(
          AuthApi(createTestApiService(backend, tokenStore: tokenStore)),
          tokenStore,
          InMemoryKeyValueStore(),
        ),
      );
      purchases = FakePurchaseService();
      controller = EntitlementController(
        auth,
        PurchaseRepository(purchaseService: purchases),
      );

      addTearDown(controller.dispose);
      addTearDown(auth.dispose);
      await auth.bootstrap();

      await auth.register(
        email: testEmail,
        password: testPassword,
        displayName: testName,
      );
    });

    test('satın alma mağaza sahte servisinden geçip sunucuya PATCH atar',
        () async {
      final success = await controller.purchase(ProductId.aiPro);

      expect(success, isTrue);
      expect(purchases.purchasedProducts, [ProductId.aiPro]);
      expect(backend.subscriptionOf(testEmail), 'ai_pro');
      expect(controller.aiUnlocked, isTrue);

      final patches = backend.requests.where(
        (request) =>
            request.method.toUpperCase() == 'PATCH' &&
            request.path.endsWith('/auth/me/subscription'),
      );
      expect(patches, isNotEmpty);
      expect(
        (patches.last.data as Map)['subscription_status'],
        'ai_pro',
      );
    });

    test('sandbox hatası kullanıcıya türüyle döner', () async {
      purchases.purchaseError = const PurchaseException(
        'Sandbox makbuzu doğrulanamadı.',
        kind: PurchaseFailureKind.sandbox,
      );

      final success = await controller.purchase(ProductId.lifetimeTests);

      expect(success, isFalse);
      expect(controller.lastFailureIsSandbox, isTrue);
      expect(controller.errorMessage, contains('Sandbox'));
      expect(controller.allTestsUnlocked, isFalse);
    });
  });

  group('PurchaseConfig', () {
    test('kaynak kodundaki fallback anahtarlar boş bırakılır', () {
      expect(PurchaseConfig.appleFallbackKey, isEmpty);
      expect(PurchaseConfig.googleFallbackKey, isEmpty);
    });

    test('ürün ve entitlement kimlikleri panel ile uyumludur', () {
      expect(
        PurchaseConfig.lifetimeTestsProductId,
        ProductId.lifetimeTests.storeIdentifier,
      );
      expect(PurchaseConfig.aiProProductId, ProductId.aiPro.storeIdentifier);
      expect(PurchaseConfig.proAccessEntitlement, 'pro_access');
      expect(PurchaseConfig.lifetimeTestsEntitlement, 'lifetime_tests');
      expect(PurchaseConfig.aiProEntitlementAlias, 'ai_pro');
    });
  });
}

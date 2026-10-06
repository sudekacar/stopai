import 'package:flutter_test/flutter_test.dart';
import 'package:stop_ai_ehliyet_kocu/core/network/api_exception.dart';
import 'package:stop_ai_ehliyet_kocu/core/storage/key_value_store.dart';
import 'package:stop_ai_ehliyet_kocu/core/storage/token_store.dart';
import 'package:stop_ai_ehliyet_kocu/features/auth/data/auth_api.dart';
import 'package:stop_ai_ehliyet_kocu/features/auth/data/auth_repository.dart';
import 'package:stop_ai_ehliyet_kocu/features/auth/domain/app_user.dart';
import 'package:stop_ai_ehliyet_kocu/features/auth/domain/auth_validators.dart';
import 'package:stop_ai_ehliyet_kocu/features/auth/presentation/auth_controller.dart';
import 'package:stop_ai_ehliyet_kocu/features/purchase/domain/subscription_status.dart';

import '../helpers/fake_backend.dart';
import '../helpers/pump_app.dart';

void main() {
  late FakeBackend backend;
  late InMemoryKeyValueStore store;
  late InMemoryTokenStore tokenStore;
  late AuthRepository repository;

  setUp(() {
    backend = FakeBackend();
    store = InMemoryKeyValueStore();
    tokenStore = InMemoryTokenStore();
    repository = AuthRepository(
      AuthApi(createTestApiService(backend, tokenStore: tokenStore)),
      tokenStore,
      store,
    );
  });

  group('AuthValidators', () {
    test('e-posta biçimi denetlenir', () {
      expect(AuthValidators.email(testEmail), isNull);
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email('surucu'), isNotNull);
      expect(AuthValidators.email('surucu@stopkoc'), isNotNull);
    });

    test('şifre en az 6 karakter, harf ve rakam içerir', () {
      expect(AuthValidators.password('Sifre123'), isNull);
      expect(AuthValidators.password('abc12'), isNotNull);
      expect(AuthValidators.password('sadeceharf'), isNotNull);
      expect(AuthValidators.password('123456'), isNotNull);
    });
  });

  group('AppUser', () {
    test('baş harfler ad soyaddan üretilir', () {
      final user = AppUser(
        id: 1,
        email: testEmail,
        displayName: 'Ali Veli',
        subscriptionStatus: SubscriptionStatus.free,
        createdAt: DateTime(2026),
      );

      expect(user.initials, 'AV');
    });

    test('ad kaydı yoksa e-postadan okunabilir isim türetilir', () {
      expect(AppUser.displayNameFromEmail('ali.veli@stopkoc.com'), 'Ali Veli');
      expect(AppUser.displayNameFromEmail('surucu@stopkoc.com'), 'Surucu');
    });
  });

  group('AuthRepository - kayıt', () {
    test('kayıt anahtarı güvenli depoya yazar', () async {
      final user = await repository.register(
        email: testEmail,
        password: testPassword,
        displayName: testName,
      );

      expect(user.email, testEmail);
      expect(user.displayName, testName);
      expect(user.subscriptionStatus, SubscriptionStatus.free);
      expect(await tokenStore.read(), isNotEmpty);
    });

    test('e-posta sunucuda normalize edilip öyle döner', () async {
      final user = await repository.register(
        email: '  Surucu@StopKoc.COM ',
        password: testPassword,
        displayName: testName,
      );

      expect(user.email, testEmail);
    });

    test('aynı e-posta ikinci kez reddedilir', () async {
      await repository.register(
        email: testEmail,
        password: testPassword,
        displayName: testName,
      );

      await expectLater(
        repository.register(
          email: testEmail,
          password: testPassword,
          displayName: 'Başka Kişi',
        ),
        throwsA(
          isA<ApiException>().having((e) => e.isConflict, 'isConflict', isTrue),
        ),
      );
    });

    test('şifre hiçbir yerde saklanmaz', () async {
      await repository.register(
        email: testEmail,
        password: testPassword,
        displayName: testName,
      );

      // Cihazda yalnızca anahtar ve profil önbelleği var; şifre yok.
      expect(store.getString('auth.cached_user'), isNot(contains(testPassword)));
      expect(await tokenStore.read(), isNot(contains(testPassword)));
    });
  });

  group('AuthRepository - giriş', () {
    setUp(() {
      backend.seedUser(email: testEmail, password: testPassword);
    });

    test('doğru şifreyle giriş yapılır', () async {
      final user = await repository.login(
        email: testEmail,
        password: testPassword,
      );

      expect(user.email, testEmail);
      expect(await tokenStore.read(), isNotEmpty);
    });

    test('yanlış şifre reddedilir ve anahtar yazılmaz', () async {
      await expectLater(
        repository.login(email: testEmail, password: 'Yanlis999'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'E-posta veya şifre hatalı.'),
        ),
      );

      expect(await tokenStore.read(), isNull);
    });

    test('bu cihazda kayıtlı ad soyad girişte geri gelir', () async {
      // Aynı cihazda kayıt olup çıkış yapan kullanıcı tekrar girdiğinde adı
      // korunmalı (backend ad alanı tutmuyor).
      backend.seedUser(email: 'yeni@stopkoc.com', password: testPassword);
      await repository.register(
        email: 'kayitli@stopkoc.com',
        password: testPassword,
        displayName: 'Zeynep Kaya',
      );
      await repository.logout();

      final user = await repository.login(
        email: 'kayitli@stopkoc.com',
        password: testPassword,
      );

      expect(user.displayName, 'Zeynep Kaya');
    });

    test('başka cihazda açılan hesapta ad e-postadan türetilir', () async {
      final user = await repository.login(
        email: testEmail,
        password: testPassword,
      );

      expect(user.displayName, 'Surucu');
    });
  });

  group('AuthRepository - oturum geri yükleme', () {
    test('anahtar yoksa oturum açılmaz', () async {
      expect(await repository.restoreSession(), isNull);
    });

    test('geçerli anahtarla kullanıcı sunucudan okunur', () async {
      await repository.register(
        email: testEmail,
        password: testPassword,
        displayName: testName,
      );

      final restored = await repository.restoreSession();

      expect(restored?.email, testEmail);
      expect(restored?.displayName, testName);
    });

    test('sunucu anahtarı reddederse oturum temizlenir', () async {
      await tokenStore.write('gecersiz-anahtar');

      expect(await repository.restoreSession(), isNull);
      expect(await tokenStore.read(), isNull);
    });

    test('sunucuya ulaşılamazsa önbellekteki profille devam edilir', () async {
      await repository.register(
        email: testEmail,
        password: testPassword,
        displayName: testName,
      );

      backend.offline = true;
      final restored = await repository.restoreSession();

      // Çevrimdışı açılışta kullanıcı giriş ekranına atılmaz.
      expect(restored?.email, testEmail);
      expect(restored?.displayName, testName);
      expect(await tokenStore.read(), isNotEmpty);
    });

    test('çıkış anahtarı ve önbelleği siler', () async {
      await repository.register(
        email: testEmail,
        password: testPassword,
        displayName: testName,
      );

      await repository.logout();

      expect(await tokenStore.read(), isNull);
      expect(store.getString('auth.cached_user'), isNull);
    });
  });

  group('AuthRepository - paket güncelleme', () {
    test('paket durumu sunucuya yazılır', () async {
      await repository.register(
        email: testEmail,
        password: testPassword,
        displayName: testName,
      );

      final user = await repository.updateSubscription(SubscriptionStatus.aiPro);

      expect(user.subscriptionStatus, SubscriptionStatus.aiPro);
      expect(backend.subscriptionOf(testEmail), 'ai_pro');
    });
  });

  group('AuthController', () {
    late AuthController controller;

    setUp(() {
      controller = AuthController(repository);
      addTearDown(controller.dispose);
    });

    test('oturum durumu: bilinmeyen -> giriş yapılmamış -> açık', () async {
      expect(controller.status, AuthStatus.unknown);

      await controller.bootstrap();
      expect(controller.status, AuthStatus.unauthenticated);

      final success = await controller.register(
        email: testEmail,
        password: testPassword,
        displayName: testName,
      );

      expect(success, isTrue);
      expect(controller.status, AuthStatus.authenticated);
      expect(controller.isBusy, isFalse);
      expect(controller.errorMessage, isNull);
    });

    test('başarısız giriş hata mesajı bırakır', () async {
      await controller.bootstrap();

      final success = await controller.login(
        email: 'yok@stopkoc.com',
        password: testPassword,
      );

      expect(success, isFalse);
      expect(controller.isSignedIn, isFalse);
      expect(controller.errorMessage, 'E-posta veya şifre hatalı.');

      controller.clearError();
      expect(controller.errorMessage, isNull);
    });

    test('ağ hatası kullanıcıya anlaşılır mesajla bildirilir', () async {
      await controller.bootstrap();
      backend.offline = true;

      final success = await controller.login(
        email: testEmail,
        password: testPassword,
      );

      expect(success, isFalse);
      expect(controller.errorMessage, contains('Sunucuya ulaşılamıyor'));
    });

    test('oturum süresi dolduğunda kullanıcı çıkışa alınır', () async {
      await controller.bootstrap();
      await controller.register(
        email: testEmail,
        password: testPassword,
        displayName: testName,
      );

      await controller.handleSessionExpired();

      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.user, isNull);
      expect(controller.errorMessage, contains('Oturum süresi doldu'));
    });

    test('çıkış yapınca oturum kapanır', () async {
      await controller.bootstrap();
      await controller.register(
        email: testEmail,
        password: testPassword,
        displayName: testName,
      );

      await controller.logout();

      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.user, isNull);
    });
  });
}

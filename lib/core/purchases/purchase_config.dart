import 'package:flutter/foundation.dart';

/// RevenueCat panelindeki ürün / entitlement kimlikleri ve API anahtarları.
///
/// Panel eşlemesi (dashboard'daki identifier'lar birebir bunlar olmalı):
///
/// | Mağaza ürün kimliği            | Entitlement     | Backend `subscription_status` |
/// |--------------------------------|-----------------|-------------------------------|
/// | `com.stopkoc.lifetime_tests`   | `lifetime_tests`| `lifetime_tests`              |
/// | `com.stopkoc.ai_pro`           | `pro_access`    | `ai_pro`                      |
///
/// `pro_access` yoksa `ai_pro` entitlement adı da kabul edilir.
///
/// API anahtarı önceliği:
/// 1. `--dart-define=REVENUECAT_APPLE_API_KEY` / `REVENUECAT_GOOGLE_API_KEY`
/// 2. `--dart-define=REVENUECAT_API_KEY` (tek anahtar, her iki mağaza)
/// 3. Aşağıdaki fallback sabitleri (geliştirme placeholder; kaynağa gerçek
///    anahtar koyulmaz — boş bırakılır)
abstract final class PurchaseConfig {
  /// App Store Connect / Play Console'daki ömür boyu test paketi.
  static const String lifetimeTestsProductId = 'com.stopkoc.lifetime_tests';

  /// App Store Connect / Play Console'daki AI Pro paketi.
  static const String aiProProductId = 'com.stopkoc.ai_pro';

  /// RevenueCat entitlement: AI çalışma alanı.
  static const String proAccessEntitlement = 'pro_access';

  /// RevenueCat'te AI paketi `ai_pro` adıyla tanımlanmışsa da tanınır.
  static const String aiProEntitlementAlias = 'ai_pro';

  /// RevenueCat entitlement: 2-20 testlerin kilidi.
  static const String lifetimeTestsEntitlement = 'lifetime_tests';

  static const String _appleFromEnvironment = String.fromEnvironment(
    'REVENUECAT_APPLE_API_KEY',
    defaultValue: '',
  );

  static const String _googleFromEnvironment = String.fromEnvironment(
    'REVENUECAT_GOOGLE_API_KEY',
    defaultValue: '',
  );

  static const String _sharedFromEnvironment = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: '',
  );

  /// Dart-define yoksa kullanılan Apple yedeği (`appl_...`).
  /// Geliştirmede buraya test anahtarı yazılabilir; boşken SDK başlatılmaz.
  static const String appleFallbackKey = '';

  /// Dart-define yoksa kullanılan Google yedeği (`goog_...`).
  static const String googleFallbackKey = '';

  /// Apple public SDK anahtarı: dart-define, yoksa fallback.
  static String get appleApiKey =>
      _firstNonEmpty([_appleFromEnvironment, appleFallbackKey]);

  /// Google public SDK anahtarı: dart-define, yoksa fallback.
  static String get googleApiKey =>
      _firstNonEmpty([_googleFromEnvironment, googleFallbackKey]);

  /// Bu platform için kullanılacak anahtar. Boşsa [PurchaseService.init]
  /// SDK'yı başlatmaz.
  static String get platformApiKey {
    if (_isAndroidDevice) {
      return _firstNonEmpty([
        _googleFromEnvironment,
        _sharedFromEnvironment,
        googleFallbackKey,
      ]);
    }
    return _firstNonEmpty([
      _appleFromEnvironment,
      _sharedFromEnvironment,
      appleFallbackKey,
    ]);
  }

  /// Anahtarın nereden geldiği; loglarda tam anahtar basılmasın diye.
  static PurchaseApiKeySource get apiKeySource {
    if (_isAndroidDevice) {
      if (_googleFromEnvironment.isNotEmpty) {
        return PurchaseApiKeySource.dartDefineGoogle;
      }
      if (_sharedFromEnvironment.isNotEmpty) {
        return PurchaseApiKeySource.dartDefineShared;
      }
      if (googleFallbackKey.isNotEmpty) {
        return PurchaseApiKeySource.fallbackGoogle;
      }
      return PurchaseApiKeySource.missing;
    }
    if (_appleFromEnvironment.isNotEmpty) {
      return PurchaseApiKeySource.dartDefineApple;
    }
    if (_sharedFromEnvironment.isNotEmpty) {
      return PurchaseApiKeySource.dartDefineShared;
    }
    if (appleFallbackKey.isNotEmpty) {
      return PurchaseApiKeySource.fallbackApple;
    }
    return PurchaseApiKeySource.missing;
  }

  static bool get isConfigured => platformApiKey.isNotEmpty;

  /// Mağaza SDK'sı yalnızca iOS ve Android'de çalışır.
  static bool get isStoreSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  static bool get _isAndroidDevice =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.isNotEmpty) return value;
    }
    return '';
  }
}

/// [PurchaseConfig.platformApiKey] çözümünün kaynağı.
enum PurchaseApiKeySource {
  dartDefineApple,
  dartDefineGoogle,
  dartDefineShared,
  fallbackApple,
  fallbackGoogle,
  missing,
}

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../features/ai/data/ai_api.dart';
import '../features/ai/data/ai_coach_service.dart';
import '../features/ai/data/image_picker_service.dart';
import '../features/ai/presentation/ai_coach_controller.dart';
import '../features/auth/data/auth_api.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/profile/data/results_api.dart';
import '../features/profile/data/stats_repository.dart';
import '../features/profile/presentation/stats_controller.dart';
import '../features/purchase/data/purchase_repository.dart';
import '../features/purchase/presentation/entitlement_controller.dart';
import 'ads/ad_manager.dart';
import 'network/api_exception.dart';
import 'network/api_service.dart';
import 'network/network_status.dart';
import 'notifications/push_notification_service.dart';
import 'observability/crash_reporter.dart';
import 'services/purchase_service.dart';
import 'storage/key_value_store.dart';

/// Uygulamanın tüm paylaşılan servislerini kurar ve birbirine bağlar.
///
/// Bağımlılık enjeksiyonu için ek bir paket kullanmıyoruz; tek bir örnek
/// [AppScope] ile widget ağacına veriliyor.
class AppServices {
  AppServices({
    required this.store,
    required this.api,
    ImagePickerService? imagePicker,
    this.purchaseService,
    CrashReporter? crashReporter,
    NetworkStatus? network,
    PushNotificationService? pushNotifications,
  })  : ads = AdManager(),
        crashReporter = crashReporter ?? const CrashReporter(),
        network = network ?? NetworkStatus(),
        pushNotifications = pushNotifications ?? const PushNotificationService(),
        _imagePicker = imagePicker ?? DeviceImagePicker(),
        _aiService = AiCoachService(AiApi(api)) {
    auth = AuthController(
      AuthRepository(AuthApi(api), api.tokenStore, store),
    );
    entitlement = EntitlementController(
      auth,
      PurchaseRepository(purchaseService: purchaseService),
      this.crashReporter,
    );
    stats = StatsController(StatsRepository(ResultsApi(api), store));

    // Sunucu anahtarı reddettiğinde kullanıcı giriş ekranına döner.
    api.onUnauthorized = auth.handleSessionExpired;

    auth.addListener(_onAuthChanged);
    entitlement.addListener(_onEntitlementChanged);
    this.network.onWentOnline = _onBackOnline;
    purchaseService?.addCustomerInfoListener(_onStoreCustomerInfo);
  }

  final KeyValueStore store;
  final ApiService api;
  final AdManager ads;
  final PurchaseService? purchaseService;
  final CrashReporter crashReporter;
  final NetworkStatus network;
  final PushNotificationService pushNotifications;

  final ImagePickerService _imagePicker;
  final AiCoachService _aiService;

  late final AuthController auth;
  late final EntitlementController entitlement;
  late final StatsController stats;

  bool _userLoaded = false;
  String? _loadedEmail;
  Future<void>? _statsLoad;
  Future<void>? _purchasesSync;

  /// AI sekmesi her açıldığında kendi sohbet durumunu kullanır.
  AiCoachController createAiCoachController() =>
      AiCoachController(_aiService, _imagePicker);

  /// Açılışta kayıtlı oturumu sunucuya doğrulatır; istatistikler ve haklar
  /// dinleyici üzerinden yüklenir.
  Future<void> bootstrap() async {
    await crashReporter.init();
    await ads.initialize();
    await purchaseService?.init();
    await network.start();
    await pushNotifications.init();
    await auth.bootstrap();
    await waitForPendingWork();
  }

  /// Oturum değişince başlayan istatistik yüklemesinin bitmesini bekler.
  Future<void> waitForPendingWork() async {
    final load = _statsLoad;
    if (load != null) await load;
    final purchases = _purchasesSync;
    if (purchases != null) await purchases;
  }

  /// Oturum sahibi değiştiğinde kullanıcıya ait verileri yeniden yükler.
  void _onAuthChanged() {
    final email = auth.user?.email;
    if (_userLoaded && email == _loadedEmail) return;

    _userLoaded = true;
    _loadedEmail = email;

    // Reklam durumu haklardan türetiliyor; oturum değişince hemen güncelle.
    _onEntitlementChanged();
    _statsLoad = stats.loadFor(email);
    _purchasesSync = _syncPurchasesUser();
    crashReporter.setUserId(auth.user?.id.toString());
    pushNotifications.syncUser(auth.user?.id.toString());
  }

  /// Girişte RevenueCat kullanıcı kimliğini eşler; mağazada hak varsa
  /// sunucudaki `subscription_status` da güncellenir.
  Future<void> _syncPurchasesUser() async {
    final purchases = purchaseService;
    if (purchases == null || !purchases.isReady) {
      await auth.syncPendingSubscription();
      return;
    }

    final user = auth.user;
    if (user == null) {
      await purchases.logOutUser();
      return;
    }

    try {
      final result = await purchases.loginUser(user.id.toString());
      final merged = user.subscriptionStatus.merge(result.status);
      if (merged != user.subscriptionStatus) {
        await auth.applySubscription(merged);
      } else {
        await auth.syncPendingSubscription();
      }
    } on PurchaseException catch (error, stack) {
      if (!error.cancelled) {
        await crashReporter.recordError(error, stack);
      }
      if (kDebugMode && !error.cancelled) {
        debugPrint('[AppServices] RevenueCat login: ${error.message}');
      }
    } on ApiException catch (error, stack) {
      await crashReporter.recordError(error, stack);
      if (kDebugMode) {
        debugPrint('[AppServices] abonelik senkronu: ${error.message}');
      }
    }
  }

  void _onStoreCustomerInfo(StorePurchaseResult result) {
    final user = auth.user;
    if (user == null || result.cancelled) return;
    final merged = user.subscriptionStatus.merge(result.status);
    if (merged == user.subscriptionStatus) return;
    _purchasesSync = auth.applySubscription(merged);
  }

  void _onBackOnline() {
    _statsLoad = stats.syncWhenOnline();
    _purchasesSync = auth.syncPendingSubscription();
  }

  /// Satın alma durumu reklamları doğrudan etkiler.
  void _onEntitlementChanged() {
    ads.setAdsEnabled(!entitlement.adsRemoved);
  }

  void dispose() {
    auth.removeListener(_onAuthChanged);
    entitlement.removeListener(_onEntitlementChanged);
    purchaseService?.removeCustomerInfoListener(_onStoreCustomerInfo);
    network.onWentOnline = null;
    auth.dispose();
    entitlement.dispose();
    stats.dispose();
    ads.dispose();
    network.dispose();
  }
}

/// Servisleri widget ağacına taşır.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope widget ağacında bulunamadı');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.services != services;
}

import 'package:flutter/foundation.dart';

import '../../../core/safe_notifier.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/observability/crash_reporter.dart';
import '../../../core/services/purchase_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/purchase_repository.dart';
import '../domain/entitlement.dart';
import '../domain/purchase_product.dart';
import '../domain/subscription_status.dart';

/// Kilitlerin ve reklam durumunun uygulama genelindeki tek kaynağı.
///
/// Satın alma RevenueCat üzerinden yürür; kazanılan hak önce yerelde açılır,
/// ardından sunucudaki `subscription_status` alanına yazılır.
class EntitlementController extends ChangeNotifier with SafeNotifier {
  EntitlementController(
    this._auth, [
    this._repository = const PurchaseRepository(),
    this._crash = const CrashReporter(),
  ])  : _products = PurchaseCatalog.products {
    _auth.addListener(_onAuthChanged);
  }

  final AuthController _auth;
  final PurchaseRepository _repository;
  final CrashReporter _crash;

  List<PurchaseProduct> _products;
  ProductId? _purchasingProduct;
  String? _errorMessage;
  bool _loadingOfferings = false;
  PurchaseFailureKind? _lastFailureKind;

  /// Oturumu açık kullanıcının hakları; giriş yapılmamışsa hiçbiri.
  Entitlement get entitlement {
    final status = _auth.user?.subscriptionStatus;
    return status == null ? Entitlement.none : Entitlement.fromStatus(status);
  }

  /// O anda satın alınmakta olan paket; yoksa `null`.
  ProductId? get purchasingProduct => _purchasingProduct;

  bool get isPurchasing => _purchasingProduct != null;
  bool get isLoadingOfferings => _loadingOfferings;
  String? get errorMessage => _errorMessage;
  PurchaseFailureKind? get lastFailureKind => _lastFailureKind;
  bool get lastFailureIsSandbox =>
      _lastFailureKind == PurchaseFailureKind.sandbox;

  List<PurchaseProduct> get products => _products;

  bool get allTestsUnlocked => entitlement.allTestsUnlocked;
  bool get aiUnlocked => entitlement.aiUnlocked;
  bool get adsRemoved => entitlement.adsRemoved;

  /// Mağazadaki güncel teklifleri (fiyatlar) çeker.
  Future<void> refreshOfferings() async {
    if (_loadingOfferings) return;
    _loadingOfferings = true;
    safeNotifyListeners();

    try {
      _products = await _repository.loadStoreOfferings();
    } on PurchaseException {
      _products = PurchaseCatalog.products;
    } finally {
      _loadingOfferings = false;
      safeNotifyListeners();
    }
  }

  /// Satın alma: mağaza ödemesi tamamlanınca hak yerelde hemen açılır,
  /// ardından `PATCH /auth/me/subscription` ile sunucuya yazılır.
  Future<bool> purchase(ProductId productId) async {
    if (isPurchasing) return false;

    _purchasingProduct = productId;
    _errorMessage = null;
    _lastFailureKind = null;
    safeNotifyListeners();

    try {
      final purchased = await _repository.purchaseFromStore(productId);
      final current =
          _auth.user?.subscriptionStatus ?? SubscriptionStatus.free;
      try {
        await _auth.applySubscription(current.merge(purchased));
      } on ApiException catch (error) {
        _errorMessage = error.isNetworkError
            ? 'Paket açıldı. Sunucuya kayıt çevrimiçi olunca tamamlanacak.'
            : 'Paket açıldı ancak sunucu kaydı: ${error.message}';
      }
      return true;
    } on PurchaseException catch (error) {
      if (!error.cancelled) {
        _errorMessage = error.message;
        _lastFailureKind = error.kind;
      }
      return false;
    } on ApiException catch (error, stack) {
      _errorMessage = error.message;
      await _crash.recordError(error, stack);
      return false;
    } on Object catch (error, stack) {
      _errorMessage = 'Satın alma tamamlanamadı. Lütfen tekrar deneyin.';
      _lastFailureKind = PurchaseFailureKind.unknown;
      await _crash.recordError(error, stack);
      return false;
    } finally {
      _purchasingProduct = null;
      safeNotifyListeners();
    }
  }

  /// "Satın alımlarımı geri yükle": önce mağaza, sonra sunucu.
  Future<void> restore() async {
    _errorMessage = null;
    _lastFailureKind = null;
    safeNotifyListeners();

    try {
      final restored = await _repository.restorePurchases();
      if (restored != SubscriptionStatus.free) {
        final current =
            _auth.user?.subscriptionStatus ?? SubscriptionStatus.free;
        await _auth.applySubscription(current.merge(restored));
        return;
      }
      await _auth.refreshUser();
    } on PurchaseException catch (error) {
      if (!error.cancelled) {
        _errorMessage = error.message;
        _lastFailureKind = error.kind;
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    }
    safeNotifyListeners();
  }

  void clearError() {
    if (_errorMessage == null && _lastFailureKind == null) return;
    _errorMessage = null;
    _lastFailureKind = null;
    safeNotifyListeners();
  }

  /// Kullanıcı ya da paket durumu değiştiğinde dinleyicileri uyar.
  void _onAuthChanged() => safeNotifyListeners();

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}

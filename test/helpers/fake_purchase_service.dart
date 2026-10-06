import 'package:stop_ai_ehliyet_kocu/core/services/purchase_service.dart';
import 'package:stop_ai_ehliyet_kocu/features/purchase/domain/purchase_product.dart';

/// RevenueCat olmadan çalışan mağaza taklidi; unit/widget testleri buna bağlanır.
class FakePurchaseService extends PurchaseService {
  FakePurchaseService({
    this.isReady = true,
    this.purchaseResult,
    this.offerings = PurchaseCatalog.products,
  });

  @override
  bool isReady;

  StorePurchaseResult? purchaseResult;
  PurchaseException? purchaseError;
  List<PurchaseProduct> offerings;

  final List<ProductId> purchasedProducts = [];
  final List<String> loggedInUserIds = [];
  int restoreCount = 0;
  int initCount = 0;
  int logOutCount = 0;

  void stubPurchase(StorePurchaseResult result) => purchaseResult = result;

  @override
  Future<void> init() async {
    initCount++;
  }

  @override
  Future<List<PurchaseProduct>> loadOfferings() async => offerings;

  @override
  Future<StorePurchaseResult> purchaseProduct(ProductId productId) async {
    purchasedProducts.add(productId);
    final error = purchaseError;
    if (error != null) throw error;
    return purchaseResult ??
        StorePurchaseResult.fromStatus(productId.grantedStatus);
  }

  @override
  Future<StorePurchaseResult> restorePurchases() async {
    restoreCount++;
    return purchaseResult ?? const StorePurchaseResult.empty();
  }

  @override
  Future<StorePurchaseResult> loginUser(String userId) async {
    loggedInUserIds.add(userId);
    return purchaseResult ?? const StorePurchaseResult.empty();
  }

  @override
  Future<void> logOutUser() async {
    logOutCount++;
  }
}

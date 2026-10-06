import 'subscription_status.dart';

/// Kullanıcının satın aldığı hakların birleşimi.
///
/// Tek kaynak sunucudaki `subscription_status` alanıdır; bu sınıf onu
/// arayüzün sorduğu sorulara ("AI açık mı?", "reklam gösterilsin mi?")
/// çeviren ince bir katman.
class Entitlement {
  const Entitlement._(this.status);

  factory Entitlement.fromStatus(SubscriptionStatus status) =>
      Entitlement._(status);

  factory Entitlement.fromApi(String? value) =>
      Entitlement._(SubscriptionStatus.fromApi(value));

  static const Entitlement none = Entitlement._(SubscriptionStatus.free);

  final SubscriptionStatus status;

  bool get hasAnyPurchase => status != SubscriptionStatus.free;

  /// Tüm testlerin kilidi açık mı. AI Pro üst paket olduğu için testleri içerir.
  bool get allTestsUnlocked => hasAnyPurchase;

  /// AI çalışma alanına erişim.
  bool get aiUnlocked => status == SubscriptionStatus.aiPro;

  /// Herhangi bir satın alma reklamları kaldırır.
  bool get adsRemoved => hasAnyPurchase;

  /// Profilde gösterilen üyelik etiketi.
  String get planLabel => status.label;

  @override
  bool operator ==(Object other) =>
      other is Entitlement && other.status == status;

  @override
  int get hashCode => status.hashCode;

  @override
  String toString() => 'Entitlement(${status.apiValue})';
}

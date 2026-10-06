/// Kullanıcının paket durumu; backend'deki `users.subscription_status`
/// kolonuyla birebir aynı değerleri taşır.
enum SubscriptionStatus {
  /// Yalnızca 1. deneme testi açık, reklamlar görünür.
  free('free'),

  /// 99 TL paketi: 2-20 arası testler açık.
  lifetimeTests('lifetime_tests'),

  /// 299 TL paketi: AI çalışma alanı da açık.
  aiPro('ai_pro');

  const SubscriptionStatus(this.apiValue);

  /// Sunucunun beklediği/döndürdüğü metin değeri.
  final String apiValue;

  /// Bilinmeyen bir değer gelirse en kısıtlı duruma düşer: sunucu yeni bir
  /// paket eklediğinde eski istemci kilitleri açmak yerine kapalı tutar.
  static SubscriptionStatus fromApi(String? value) {
    for (final status in values) {
      if (status.apiValue == value) return status;
    }
    return SubscriptionStatus.free;
  }

  /// Daha kapsamlı paket kazanır: AI Pro, ömür boyu testlerin üstündedir.
  SubscriptionStatus merge(SubscriptionStatus other) =>
      index >= other.index ? this : other;

  /// Profilde gösterilen üyelik etiketi.
  String get label => switch (this) {
        SubscriptionStatus.free => 'Ücretsiz Kullanıcı',
        SubscriptionStatus.lifetimeTests => 'Ömür Boyu Test Paketi Aktif',
        SubscriptionStatus.aiPro => 'AI Pro Paket Aktif',
      };
}

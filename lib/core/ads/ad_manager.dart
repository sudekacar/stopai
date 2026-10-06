import 'package:flutter/foundation.dart';

import 'ad_config.dart';

/// Reklam gösterimini yöneten tek nokta.
///
/// Henüz bir reklam SDK'sı bağlı değil: sınıf "kaç soru tamamlandı" sayacını
/// tutar ve sırası gelince [interstitialAdTrigger] çağrılır. AdMob eklendiğinde
/// yalnızca [initialize] ve [interstitialAdTrigger] gövdeleri dolacak,
/// çağıran ekranlarda değişiklik gerekmeyecek.
///
/// [ChangeNotifier] olmasının tek nedeni [adsEnabled] değiştiğinde banner
/// yuvasının kendini yeniden çizmesi.
class AdManager extends ChangeNotifier {
  AdManager();

  bool _adsEnabled = true;
  int _completedQuestionCount = 0;
  int _interstitialTriggerCount = 0;

  /// Reklamların gösterilip gösterilmeyeceği. Kullanıcı paket satın alınca
  /// [setAdsEnabled] ile kapatılır.
  bool get adsEnabled => _adsEnabled;

  /// Tamamlanan (cevaplanıp geçilen) soru sayısı.
  int get completedQuestionCount => _completedQuestionCount;

  /// [interstitialAdTrigger] kaç kez çağrıldı. Test ve analitik için.
  int get interstitialTriggerCount => _interstitialTriggerCount;

  /// Geçiş reklamı tetiklendiğinde haber verilir.
  ///
  /// SDK bağlanana kadar arayüzün bir yer tutucu gösterebilmesi için var;
  /// entegrasyondan sonra kaldırılabilir.
  VoidCallback? onInterstitialTriggered;

  /// Reklam SDK'sının başlatılacağı yer (`MobileAds.instance.initialize()`).
  Future<void> initialize() async {
    // TODO(ads): AdMob başlatma ve ilk interstitial'ı ön yükleme.
  }

  /// Reklamları açar/kapatır. Satın alma durumu değiştiğinde çağrılır.
  void setAdsEnabled(bool value) {
    if (_adsEnabled == value) return;
    _adsEnabled = value;
    notifyListeners();
  }

  /// Bir soru tamamlandığında çağrılır.
  ///
  /// Sayaç [AdConfig.interstitialQuestionInterval] katına ulaştığında geçiş
  /// reklamını tetikler. Reklamlar kapalıysa sayaç ilerler ama reklam çıkmaz.
  void registerQuestionCompleted() {
    _completedQuestionCount++;
    if (!_adsEnabled) return;
    if (_completedQuestionCount % AdConfig.interstitialQuestionInterval == 0) {
      interstitialAdTrigger();
    }
  }

  /// Her 5 soruda bir çağrılan geçiş reklamı tetikleyicisi.
  ///
  /// Gövdesi bilinçli olarak boş: reklam yükleme/gösterme kodu AdMob
  /// entegrasyonunda buraya eklenecek.
  void interstitialAdTrigger() {
    _interstitialTriggerCount++;

    // TODO(ads): Yüklü interstitial'ı göster, ardından bir sonrakini yükle.

    if (kDebugMode) {
      debugPrint(
        '[AdManager] interstitialAdTrigger() -> '
        '$_completedQuestionCount. soru, $_interstitialTriggerCount. gösterim',
      );
    }
    onInterstitialTriggered?.call();
  }

  /// Yeni bir test başlarken soru sayacını sıfırlar.
  void resetQuestionCounter() {
    _completedQuestionCount = 0;
  }
}

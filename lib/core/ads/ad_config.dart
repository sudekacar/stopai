/// Reklam yerleşimiyle ilgili tüm sabitler.
///
/// Gerçek reklam kimlikleri (AdMob unit id'leri) entegrasyon adımında
/// buraya eklenecek; şimdilik yalnızca yerleşim kuralları tutuluyor.
abstract final class AdConfig {
  /// Kaç soruda bir geçiş reklamı (interstitial) tetiklenecek.
  static const int interstitialQuestionInterval = 5;

  /// Alt banner yuvasının yüksekliği. AdMob standart banner'ı 320x50,
  /// adaptive banner'da 50-60 px arası döner; yuvayı 56 px'te sabitleyip
  /// yerleşimin reklam yüklendiğinde zıplamamasını sağlıyoruz.
  static const double bannerHeight = 56;
}

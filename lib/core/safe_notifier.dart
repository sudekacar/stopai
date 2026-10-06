import 'package:flutter/foundation.dart';

/// Dispose edildikten sonra bildirim göndermeyi güvenli hâle getirir.
///
/// Kontrolcülerimiz ağ isteği başlatıp yanıtı bekliyor. Kullanıcı bu arada
/// çıkış yaparsa ya da ekran kapanırsa kontrolcü dispose edilmiş oluyor ve
/// `notifyListeners()` "used after being disposed" hatası fırlatıyor.
/// Async akışlarda [safeNotifyListeners] kullanılır.
mixin SafeNotifier on ChangeNotifier {
  bool _disposed = false;

  bool get isDisposed => _disposed;

  void safeNotifyListeners() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

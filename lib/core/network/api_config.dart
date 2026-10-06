import 'package:flutter/foundation.dart';

/// Backend bağlantı ayarları.
abstract final class ApiConfig {
  /// Derleme sırasında verilebilen adres:
  /// `flutter run --dart-define=API_BASE_URL=https://api.stopkoc.com/api/v1`
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static const String _path = '/api/v1';
  static const int _port = 9000;

  /// Kullanılacak temel adres.
  ///
  /// Android emülatöründe `localhost` emülatörün kendisini gösterdiği için
  /// ana makineye `10.0.2.2` üzerinden gidilir. iOS simülatörü ve masaüstü
  /// `localhost` kullanır.
  static String get baseUrl {
    if (_override.isNotEmpty) return _override;

    final host = _isAndroidDevice ? '10.0.2.2' : 'localhost';
    return 'http://$host:$_port$_path';
  }

  static bool get _isAndroidDevice =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Bağlantı kurma süresi. Sunucu kapalıysa kullanıcıyı uzun bekletmeyelim.
  static const Duration connectTimeout = Duration(seconds: 10);

  /// Genel istekler için yanıt bekleme süresi.
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// AI istekleri için ayrı süre: yerel Llama 3 yanıtı yavaş üretebilir,
  /// sunucu tarafındaki `OLLAMA_TIMEOUT_SECONDS` ile uyumlu tutuluyor.
  static const Duration aiReceiveTimeout = Duration(seconds: 120);
}

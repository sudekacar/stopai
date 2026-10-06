import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JWT'nin saklandığı yer.
///
/// Anahtar bir kimlik bilgisi olduğu için `shared_preferences` yerine
/// platformun güvenli deposunda (Android Keystore / iOS Keychain) tutulur.
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Cihazın güvenli deposunu kullanan gerçek uygulama.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              // Anahtar cihaz ilk kez açıldıktan sonra erişilebilir olsun;
              // arka plandaki yenileme istekleri kilit ekranında da çalışır.
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  static const String _key = 'auth.access_token';

  final FlutterSecureStorage _storage;

  /// Her istekte platform kanalına gitmemek için bellekte tutulan kopya.
  String? _cached;
  bool _loaded = false;

  @override
  Future<String?> read() async {
    if (_loaded) return _cached;

    try {
      _cached = await _storage.read(key: _key);
    } on Exception {
      // Keystore/Keychain okunamazsa oturumu yok say; kullanıcı tekrar
      // giriş yapar. Açılışta çökmekten iyidir.
      _cached = null;
    }
    _loaded = true;
    return _cached;
  }

  @override
  Future<void> write(String token) async {
    _cached = token;
    _loaded = true;
    await _storage.write(key: _key, value: token);
  }

  @override
  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    await _storage.delete(key: _key);
  }
}

/// Testler ve önizleme için bellekte tutan uygulama.
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this._token]);

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

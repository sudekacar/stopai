import '../../../core/network/api_exception.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/storage/token_store.dart';
import '../../purchase/domain/subscription_status.dart';
import '../domain/app_user.dart';
import 'auth_api.dart';

/// Oturum yönetimi.
///
/// Şifre artık cihazda hashlenmiyor; sunucu bcrypt ile hashleyip JWT
/// döndürüyor. Bu sınıf anahtarı güvenli depoya yazar ve çevrimdışı açılış
/// için son kullanıcı profilini önbellekte tutar.
class AuthRepository {
  AuthRepository(this._api, this._tokenStore, this._store);

  static const String _cachedUserKey = 'auth.cached_user';
  static const String _displayNamesKey = 'auth.display_names';
  static const String _pendingSubscriptionKey = 'auth.pending_subscription';

  final AuthApi _api;
  final TokenStore _tokenStore;
  final KeyValueStore _store;

  /// Kayıtlı anahtarla oturumu geri yükler.
  ///
  /// Anahtar sunucu tarafından reddedilirse (401) oturum temizlenir.
  /// Sunucuya ulaşılamıyorsa önbellekteki profille devam edilir: uygulama
  /// çevrimdışı da açılabilsin.
  Future<AppUser?> restoreSession() async {
    final token = await _tokenStore.read();
    if (token == null || token.isEmpty) return null;

    try {
      final remote = await _api.me();
      final user = _toAppUser(remote);
      await _cacheUser(user);
      return user;
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await logout();
        return null;
      }
      return _cachedUser();
    }
  }

  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final session = await _api.register(email: email, password: password);
    await _tokenStore.write(session.accessToken);

    // Ad soyad backend'de tutulmuyor; bu cihazda e-postaya bağlı saklanır.
    await _rememberDisplayName(session.user.email, displayName);

    final user = _toAppUser(session.user, displayName: displayName.trim());
    await _cacheUser(user);
    return user;
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final session = await _api.login(email: email, password: password);
    await _tokenStore.write(session.accessToken);

    final user = _toAppUser(session.user);
    await _cacheUser(user);
    return user;
  }

  Future<void> logout() async {
    await _tokenStore.clear();
    await _store.remove(_cachedUserKey);
    await _store.remove(_pendingSubscriptionKey);
  }

  /// Satın alma sonrası paket durumunu `PATCH /auth/me/subscription` ile
  /// sunucuya bildirir.
  Future<AppUser> updateSubscription(SubscriptionStatus status) async {
    final remote = await _api.updateSubscription(status);
    final user = _toAppUser(remote);
    await _cacheUser(user);
    await clearPendingSubscription();
    return user;
  }

  /// Mağaza ödemesi bitti ama sunucuya henüz yazılamadı: kilitler yerelde açılır.
  Future<AppUser> applyLocalSubscription(
    AppUser current,
    SubscriptionStatus status,
  ) async {
    final updated = current.copyWith(subscriptionStatus: status);
    await _cacheUser(updated);
    return updated;
  }

  Future<void> markPendingSubscription(SubscriptionStatus status) {
    return _store.setString(_pendingSubscriptionKey, status.apiValue);
  }

  Future<void> clearPendingSubscription() =>
      _store.remove(_pendingSubscriptionKey);

  SubscriptionStatus? pendingSubscription() {
    final raw = _store.getString(_pendingSubscriptionKey);
    if (raw == null || raw.isEmpty) return null;
    return SubscriptionStatus.fromApi(raw);
  }

  // --------------------------------------------------------- Yardımcılar

  AppUser _toAppUser(RemoteUser remote, {String? displayName}) {
    return AppUser(
      id: remote.id,
      email: remote.email,
      displayName: displayName?.isNotEmpty == true
          ? displayName!
          : _displayNameFor(remote.email),
      subscriptionStatus: remote.subscriptionStatus,
      createdAt: remote.createdAt,
    );
  }

  String _displayNameFor(String email) {
    final names = _store.getJson(_displayNamesKey) ?? const {};
    final stored = names[email];
    if (stored is String && stored.trim().isNotEmpty) return stored;

    // Bu cihazda kayıt olmamış kullanıcı: e-postadan okunabilir bir ad üret.
    return AppUser.displayNameFromEmail(email);
  }

  Future<void> _rememberDisplayName(String email, String displayName) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return;

    final names = {...?_store.getJson(_displayNamesKey)};
    names[email] = trimmed;
    await _store.setJson(_displayNamesKey, names);
  }

  Future<void> _cacheUser(AppUser user) =>
      _store.setJson(_cachedUserKey, user.toJson());

  AppUser? _cachedUser() {
    final json = _store.getJson(_cachedUserKey);
    if (json == null) return null;
    try {
      return AppUser.fromJson(json);
    } on Object {
      return null;
    }
  }
}

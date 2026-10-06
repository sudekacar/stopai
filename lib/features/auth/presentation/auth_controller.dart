import 'package:flutter/foundation.dart';

import '../../../core/safe_notifier.dart';

import '../../../core/network/api_exception.dart';
import '../../purchase/domain/subscription_status.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

enum AuthStatus {
  /// Oturum henüz sunucuya doğrulatılmadı.
  unknown,
  authenticated,
  unauthenticated,
}

/// Giriş/kayıt ekranlarının ve oturum durumunun tek kaynağı.
class AuthController extends ChangeNotifier with SafeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  bool _isBusy = false;
  String? _errorMessage;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  bool get isSignedIn => _status == AuthStatus.authenticated;

  /// Uygulama açılışında kayıtlı anahtarı sunucuya doğrulatır.
  Future<void> bootstrap() async {
    _user = await _repository.restoreSession();
    _status =
        _user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
    safeNotifyListeners();
  }

  Future<bool> login({required String email, required String password}) {
    return _run(() => _repository.login(email: email, password: password));
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _run(
      () => _repository.register(
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
  }

  Future<void> logout() async {
    await _repository.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    safeNotifyListeners();
  }

  /// Sunucu anahtarı reddettiğinde (401) çağrılır: kullanıcı giriş ekranına
  /// döner ama bir hata mesajı görür.
  Future<void> handleSessionExpired() async {
    if (_status != AuthStatus.authenticated) return;

    await _repository.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = 'Oturum süresi doldu, lütfen tekrar giriş yapın.';
    safeNotifyListeners();
  }

  /// Paket durumunu önce yerelde açar, sonra sunucuya yazar.
  ///
  /// Sunucu kapalıysa kilitler yine de açılır; kayıt kuyruğa alınır.
  Future<AppUser> applySubscription(SubscriptionStatus status) async {
    final current = _user;
    if (current == null) {
      throw const ApiException(message: 'Satın alma için giriş yapmalısınız.');
    }

    final local = await _repository.applyLocalSubscription(current, status);
    _user = local;
    safeNotifyListeners();

    try {
      final remote =
          await _repository.updateSubscription(local.subscriptionStatus);
      _user = remote;
      safeNotifyListeners();
      return remote;
    } on ApiException {
      await _repository.markPendingSubscription(local.subscriptionStatus);
      rethrow;
    }
  }

  /// Çevrimdışıyken kuyruğa alınan paket durumunu sunucuya gönderir.
  Future<void> syncPendingSubscription() async {
    if (!isSignedIn) return;
    final pending = _repository.pendingSubscription();
    if (pending == null) return;

    try {
      final remote = await _repository.updateSubscription(pending);
      _user = remote;
      safeNotifyListeners();
    } on ApiException {
      // Kuyruk duruyor; sonraki çevrimiçi geçişte tekrar denenecek.
    }
  }

  /// Kullanıcıyı sunucudan yeniden okur (ör. satın alımları geri yüklerken).
  Future<void> refreshUser() async {
    if (!isSignedIn) return;

    final user = await _repository.restoreSession();
    if (user == null) {
      await handleSessionExpired();
      return;
    }

    _user = user;
    safeNotifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    safeNotifyListeners();
  }

  /// Giriş ve kayıt aynı akışı paylaşır: meşgul durumu, hata yakalama ve
  /// başarıda oturumu açma.
  Future<bool> _run(Future<AppUser> Function() action) async {
    if (_isBusy) return false;

    _isBusy = true;
    _errorMessage = null;
    safeNotifyListeners();

    try {
      _user = await action();
      _status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _isBusy = false;
      safeNotifyListeners();
    }
  }
}

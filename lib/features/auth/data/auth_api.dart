import '../../../core/network/api_service.dart';
import '../../purchase/domain/subscription_status.dart';

/// Sunucudan dönen kullanıcı gövdesi (`UserRead`).
class RemoteUser {
  const RemoteUser({
    required this.id,
    required this.email,
    required this.subscriptionStatus,
    required this.createdAt,
  });

  final int id;
  final String email;
  final SubscriptionStatus subscriptionStatus;
  final DateTime createdAt;

  static RemoteUser fromJson(Map<String, dynamic> json) {
    return RemoteUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email'] as String? ?? '',
      subscriptionStatus:
          SubscriptionStatus.fromApi(json['subscription_status'] as String?),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}

/// Kayıt/giriş yanıtı (`TokenResponse`).
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;

  /// Anahtarın saniye cinsinden ömrü.
  final int expiresIn;

  final RemoteUser user;

  static AuthSession fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String? ?? '',
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 0,
      user: RemoteUser.fromJson(
        (json['user'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }
}

/// `/auth` uçlarının ince sarmalayıcısı.
class AuthApi {
  const AuthApi(this._api);

  final ApiService _api;

  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    final json = await _api.postJson(
      '/auth/register',
      body: {'email': email, 'password': password},
    );
    return AuthSession.fromJson(json);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final json = await _api.postJson(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    return AuthSession.fromJson(json);
  }

  /// Kayıtlı anahtarın hâlâ geçerli olduğunu doğrular.
  Future<RemoteUser> me() async {
    return RemoteUser.fromJson(await _api.getJson('/auth/me'));
  }

  Future<RemoteUser> updateSubscription(SubscriptionStatus status) async {
    final json = await _api.patchJson(
      '/auth/me/subscription',
      body: {'subscription_status': status.apiValue},
    );
    return RemoteUser.fromJson(json);
  }
}

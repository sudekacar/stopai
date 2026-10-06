/// Backend'in `error_code` alanında döndürdüğü değerler.
///
/// Arayüz bu kodlara bakarak farklı davranır (ör. paket gerekiyorsa
/// paywall'a yönlendirmek). `detail` alanı zaten kullanıcıya gösterilebilir
/// Türkçe metin taşır.
abstract final class ApiErrorCode {
  static const String emailAlreadyRegistered = 'email_already_registered';
  static const String invalidCredentials = 'invalid_credentials';
  static const String notAuthenticated = 'not_authenticated';
  static const String invalidToken = 'invalid_token';
  static const String tokenExpired = 'token_expired';
  static const String subscriptionRequired = 'subscription_required';
  static const String aiUnavailable = 'ai_unavailable';
  static const String aiTimeout = 'ai_timeout';
  static const String aiModelMissing = 'ai_model_missing';
  static const String aiRequestFailed = 'ai_request_failed';

  /// Sunucuya hiç ulaşılamadığında istemcinin kendi ürettiği kod.
  static const String network = 'network_error';
}

/// API çağrılarından dönen, kullanıcıya gösterilebilir hata.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.errorCode,
  });

  /// Sunucuya hiç ulaşılamadı (kapalı, yanlış adres, internet yok).
  const ApiException.network([String? message])
      : message = message ??
            'Sunucuya ulaşılamıyor. İnternet bağlantınızı ve sunucunun '
                'çalıştığını kontrol edin.',
        statusCode = null,
        errorCode = ApiErrorCode.network;

  final String message;

  /// HTTP durum kodu; ağ hatalarında `null`.
  final int? statusCode;

  final String? errorCode;

  bool get isNetworkError => errorCode == ApiErrorCode.network;

  /// Oturum geçersiz: kullanıcıyı giriş ekranına almak gerekir.
  bool get isUnauthorized => statusCode == 401;

  /// Paket gerekiyor (AI Pro).
  bool get requiresSubscription =>
      statusCode == 403 || errorCode == ApiErrorCode.subscriptionRequired;

  bool get isConflict => statusCode == 409;

  bool get isValidationError => statusCode == 422;

  /// AI servisi şu an cevap veremiyor (Ollama kapalı, model yok, zaman aşımı).
  bool get isAiUnavailable => const {
        ApiErrorCode.aiUnavailable,
        ApiErrorCode.aiModelMissing,
        ApiErrorCode.aiTimeout,
      }.contains(errorCode);

  @override
  String toString() =>
      'ApiException($statusCode, $errorCode): $message';
}

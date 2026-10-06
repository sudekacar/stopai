import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/token_store.dart';
import 'api_config.dart';
import 'api_exception.dart';

/// Backend ile tüm iletişimin geçtiği tek nokta.
///
/// Özellik katmanındaki `*_api.dart` dosyaları buradaki yardımcıları
/// kullanır; böylece anahtar ekleme, hata çevirimi ve zaman aşımı kuralları
/// tek yerde durur.
class ApiService {
  ApiService({
    required this.tokenStore,
    String? baseUrl,
    Dio? dio,
    this.onUnauthorized,
  }) : dio = dio ?? Dio() {
    this.dio.options
      ..baseUrl = baseUrl ?? ApiConfig.baseUrl
      ..connectTimeout = ApiConfig.connectTimeout
      ..receiveTimeout = ApiConfig.receiveTimeout
      ..contentType = Headers.jsonContentType
      // Gövdeyi ham metin olarak alıp kendimiz çözüyoruz: sunucu JSON
      // olmayan bir hata gövdesi döndürdüğünde (ör. ters vekil sunucunun
      // HTML hata sayfası) Dio'nun dönüştürücüsü patlayıp durumu "bağlantı
      // hatası" gibi göstermesin.
      ..responseType = ResponseType.plain
      // Hangi durum kodu gelirse gelsin yanıtı alalım; yorumlamayı
      // aşağıdaki `_send` yapıyor.
      ..validateStatus = (_) => true;

    this.dio.interceptors.add(
          InterceptorsWrapper(onRequest: _attachToken),
        );
  }

  final Dio dio;

  /// JWT'nin saklandığı depo; `AuthRepository` de aynı örneği kullanır.
  final TokenStore tokenStore;

  /// Sunucu oturumu geçersiz saydığında çağrılır (401).
  ///
  /// `AppServices` kurulum sırasında bunu `AuthController` üzerine bağlar;
  /// bu yüzden `final` değil (kontrolcü servisten sonra oluşuyor).
  Future<void> Function()? onUnauthorized;

  String get baseUrl => dio.options.baseUrl;

  Future<void> _attachToken(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenStore.read();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  // --------------------------------------------------------------- İstekler

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    Duration? receiveTimeout,
  }) {
    return _send(
      () => dio.get<dynamic>(
        path,
        queryParameters: query,
        options: Options(receiveTimeout: receiveTimeout),
      ),
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    Duration? receiveTimeout,
  }) {
    return _send(
      () => dio.post<dynamic>(
        path,
        data: body,
        options: Options(receiveTimeout: receiveTimeout),
      ),
    );
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Object? body,
  }) {
    return _send(() => dio.patch<dynamic>(path, data: body));
  }

  /// İsteği çalıştırır, hatayı [ApiException]'a çevirir.
  Future<Map<String, dynamic>> _send(
    Future<Response<dynamic>> Function() request,
  ) async {
    final Response<dynamic> response;
    try {
      response = await request();
    } on DioException catch (error) {
      throw await _mapDioException(error);
    }

    final status = response.statusCode ?? 0;
    final payload = _parseBody(response.data);

    if (status >= 200 && status < 300) {
      if (payload is Map<String, dynamic>) return payload;
      if (payload == null) return const {};
      // Liste dönen bir uç eklenirse sarmalayarak verelim.
      return {'data': payload};
    }

    if (status == 401) await onUnauthorized?.call();

    throw ApiException(
      statusCode: status,
      errorCode: _extractErrorCode(payload),
      message: _extractMessage(payload, status),
    );
  }

  /// Ham gövdeyi JSON olarak çözer; çözülemezse olduğu gibi döner.
  static dynamic _parseBody(dynamic data) {
    if (data is! String) return data;
    if (data.trim().isEmpty) return null;

    try {
      return jsonDecode(data);
    } on FormatException {
      return data;
    }
  }

  /// Yalnızca taşıma katmanı hataları buraya düşer: `validateStatus` her
  /// durum kodunu kabul ettiği için HTTP hataları `_send` içinde işlenir.
  Future<ApiException> _mapDioException(DioException error) async {
    final response = error.response;
    if (response != null) {
      final status = response.statusCode ?? 0;
      if (status == 401) await onUnauthorized?.call();

      final payload = _parseBody(response.data);
      return ApiException(
        statusCode: status,
        errorCode: _extractErrorCode(payload),
        message: _extractMessage(payload, status),
      );
    }

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.connectionError ||
      DioExceptionType.unknown =>
        const ApiException.network(),
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        const ApiException.network(
          'Sunucu yanıt vermedi. Lütfen tekrar deneyin.',
        ),
      DioExceptionType.cancel => const ApiException(
          message: 'İstek iptal edildi.',
        ),
      DioExceptionType.badCertificate => const ApiException.network(
          'Sunucu sertifikası doğrulanamadı.',
        ),
      // badResponse ve ileride eklenebilecek türler: yanıt gövdesi
      // yorumlanamadığı için genel mesaj.
      _ => ApiException(
          statusCode: error.response?.statusCode,
          message: 'Sunucu beklenmeyen bir yanıt döndürdü.',
        ),
    };
  }

  static String? _extractErrorCode(dynamic data) {
    if (data is Map && data['error_code'] is String) {
      return data['error_code'] as String;
    }
    return null;
  }

  /// Kullanıcıya gösterilecek mesajı gövdeden çıkarır.
  ///
  /// Backend iş kuralı hatalarında `detail` tek bir metin, doğrulama
  /// hatalarında (422) ise FastAPI'nin alan listesi olur.
  static String _extractMessage(dynamic data, int status) {
    if (data is Map) {
      final detail = data['detail'];

      if (detail is String && detail.isNotEmpty) return detail;

      if (detail is List && detail.isNotEmpty) {
        final messages = detail
            .whereType<Map>()
            .map((item) => item['msg'])
            .whereType<String>()
            .map(_humanizeValidationMessage)
            .toSet();
        if (messages.isNotEmpty) return messages.join('\n');
      }
    }

    if (kDebugMode) {
      debugPrint('[ApiService] Yorumlanamayan hata gövdesi ($status): $data');
    }

    return switch (status) {
      400 || 422 => 'Gönderilen bilgiler geçersiz.',
      404 => 'İstenen kayıt bulunamadı.',
      >= 500 => 'Sunucuda bir hata oluştu. Lütfen tekrar deneyin.',
      _ => 'Beklenmeyen bir hata oluştu ($status).',
    };
  }

  /// Pydantic mesajlarının başındaki teknik önekleri temizler.
  static String _humanizeValidationMessage(String message) {
    const prefix = 'Value error, ';
    return message.startsWith(prefix)
        ? message.substring(prefix.length)
        : message;
  }
}

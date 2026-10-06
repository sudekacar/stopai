import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stop_ai_ehliyet_kocu/core/network/api_exception.dart';
import 'package:stop_ai_ehliyet_kocu/core/network/api_service.dart';
import 'package:stop_ai_ehliyet_kocu/core/storage/token_store.dart';

import '../helpers/fake_backend.dart';
import '../helpers/pump_app.dart';

void main() {
  group('Anahtar eklenmesi', () {
    test('kayıtlı anahtar Authorization başlığına eklenir', () async {
      final backend = FakeBackend();
      final api = createTestApiService(
        backend,
        tokenStore: InMemoryTokenStore('abc123'),
      );

      // 404 dönecek ama isteğin başlığını görmemiz yeterli.
      await expectLater(
        api.getJson('/bilinmeyen'),
        throwsA(isA<ApiException>()),
      );

      expect(
        backend.requests.single.headers['Authorization'],
        'Bearer abc123',
      );
    });

    test('anahtar yoksa başlık eklenmez', () async {
      final backend = FakeBackend();
      final api = createTestApiService(backend);

      await expectLater(
        api.getJson('/bilinmeyen'),
        throwsA(isA<ApiException>()),
      );

      expect(
        backend.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });
  });

  group('Hata çevirimi', () {
    ApiService apiWith(ResponseBody Function(RequestOptions) handler) {
      final dio = Dio()..httpClientAdapter = _StubAdapter(handler);
      return ApiService(
        tokenStore: InMemoryTokenStore(),
        baseUrl: 'http://test/api/v1',
        dio: dio,
      );
    }

    test('sunucuya ulaşılamazsa ağ hatası döner', () async {
      final backend = FakeBackend()..offline = true;
      final api = createTestApiService(backend);

      final error = await _captureError(() => api.getJson('/auth/me'));

      expect(error.isNetworkError, isTrue);
      expect(error.statusCode, isNull);
      expect(error.message, contains('Sunucuya ulaşılamıyor'));
    });

    test('iş kuralı hatasında detail ve error_code okunur', () async {
      final api = apiWith(
        (_) => _json(409, '{"detail":"Zaten var.","error_code":"dup"}'),
      );

      final error = await _captureError(() => api.postJson('/x'));

      expect(error.statusCode, 409);
      expect(error.errorCode, 'dup');
      expect(error.message, 'Zaten var.');
      expect(error.isConflict, isTrue);
    });

    test('422 gövdesindeki alan mesajları okunabilir hâle gelir', () async {
      final api = apiWith(
        (_) => _json(
          422,
          '{"detail":[{"loc":["body","score"],'
              '"msg":"Value error, Input should be less than or equal to 100"}]}',
        ),
      );

      final error = await _captureError(() => api.postJson('/x'));

      expect(error.isValidationError, isTrue);
      // "Value error, " öneki kullanıcıya gösterilmez.
      expect(error.message, 'Input should be less than or equal to 100');
    });

    test('birden fazla doğrulama mesajı satır satır birleştirilir', () async {
      final api = apiWith(
        (_) => _json(
          422,
          '{"detail":[{"msg":"Şifre en az bir harf içermeli."},'
              '{"msg":"Şifre en az bir rakam içermeli."}]}',
        ),
      );

      final error = await _captureError(() => api.postJson('/x'));

      expect(error.message, contains('harf içermeli'));
      expect(error.message, contains('rakam içermeli'));
    });

    test('yorumlanamayan gövdede duruma uygun genel mesaj verilir', () async {
      final api = apiWith((_) => _json(500, 'bozuk gövde'));

      final error = await _captureError(() => api.getJson('/x'));

      expect(error.statusCode, 500);
      expect(error.message, contains('Sunucuda bir hata oluştu'));
    });

    test('401 alındığında oturum sonlandırma kancası tetiklenir', () async {
      var called = 0;
      final dio = Dio()
        ..httpClientAdapter = _StubAdapter(
          (_) => _json(
            401,
            '{"detail":"Yok.","error_code":"not_authenticated"}',
          ),
        );

      final api = ApiService(
        tokenStore: InMemoryTokenStore('abc'),
        baseUrl: 'http://test/api/v1',
        dio: dio,
        onUnauthorized: () async => called++,
      );

      final error = await _captureError(() => api.getJson('/auth/me'));

      expect(error.isUnauthorized, isTrue);
      expect(called, 1);
    });

    test('403 paket gerekliliği olarak işaretlenir', () async {
      final api = apiWith(
        (_) => _json(
          403,
          '{"detail":"Paket gerekli.","error_code":"subscription_required"}',
        ),
      );

      final error = await _captureError(() => api.postJson('/ai/ask'));

      expect(error.requiresSubscription, isTrue);
    });

    test('AI hataları kullanılamaz olarak sınıflanır', () async {
      for (final code in ['ai_unavailable', 'ai_model_missing', 'ai_timeout']) {
        final api = apiWith(
          (_) => _json(503, '{"detail":"AI kapalı.","error_code":"$code"}'),
        );

        final error = await _captureError(() => api.postJson('/ai/ask'));
        expect(error.isAiUnavailable, isTrue, reason: code);
      }
    });
  });
}

Future<ApiException> _captureError(Future<void> Function() action) async {
  try {
    await action();
  } on ApiException catch (error) {
    return error;
  }
  fail('ApiException beklendi ama hata fırlatılmadı.');
}

ResponseBody _json(int status, String body) => ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final ResponseBody Function(RequestOptions) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

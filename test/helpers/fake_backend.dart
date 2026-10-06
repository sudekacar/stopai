import 'dart:convert';

import 'package:dio/dio.dart';

/// Gerçek FastAPI sunucusunun testlerde kullanılan bellek içi taklidi.
///
/// Dio'nun taşıma katmanına takılır; böylece testler `ApiService`,
/// interceptor'lar ve hata çevirimi dâhil tüm ağ yolunu gerçekten geçer.
/// Yanıt gövdeleri backend'in şemalarıyla (`TokenResponse`, `StatsResponse`,
/// `AiAskResponse`) birebir aynı alanları taşır.
class FakeBackend implements HttpClientAdapter {
  FakeBackend();

  static const String basePath = '/api/v1';

  final Map<String, _FakeUser> _usersByEmail = {};
  final Map<String, _FakeUser> _usersByToken = {};
  final List<FakeResult> _results = [];

  int _nextUserId = 1;
  int _tokenCounter = 0;

  // ------------------------------------------------- Test denetim noktaları

  /// Sunucu hiç yanıt vermiyormuş gibi davranır (bağlantı hatası).
  bool offline = false;

  /// `/ai/ask` çağrıları 503 ile reddedilir (Ollama kapalı senaryosu).
  bool ollamaDown = false;

  /// `/ai/ask` yanıtı olarak dönecek metin.
  String aiAnswer =
      'Alternatör, motor çalışırken elektrik üretip aküyü şarj eder.';

  /// Modelin döndüğü isim.
  String aiModel = 'llama3';

  /// Sunucuya ulaşan istekler; beklenen gövdeyi doğrulamak için.
  final List<RequestOptions> requests = [];

  /// `/ai/ask` gövdelerinde gelen görseller.
  final List<List<String>> receivedImages = [];

  /// Kaydedilen sonuç sayısı.
  int get resultCount => _results.length;

  List<FakeResult> get results => List.unmodifiable(_results);

  /// Testin doğrudan kullanıcı oluşturması için.
  void seedUser({
    required String email,
    required String password,
    String subscriptionStatus = 'free',
  }) {
    _createUser(email: email, password: password, status: subscriptionStatus);
  }

  String? subscriptionOf(String email) =>
      _usersByEmail[email.toLowerCase()]?.subscriptionStatus;

  // ------------------------------------------------------------- Yönlendirme

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Sunucuya ulaşılamadı (test)',
      );
    }

    final path = options.path.replaceFirst(basePath, '');
    final method = options.method.toUpperCase();
    final body = _decodeBody(options.data);

    return switch ('$method $path') {
      'POST /auth/register' => _register(body),
      'POST /auth/login' => _login(body),
      'GET /auth/me' => _me(options),
      'PATCH /auth/me/subscription' => _updateSubscription(options, body),
      'POST /results' => _createResult(options, body),
      'GET /results/stats' => _stats(options),
      'POST /ai/ask' => _ask(options, body),
      'GET /ai/health' => _aiHealth(),
      _ => _json(404, {'detail': 'Bulunamadı', 'error_code': 'not_found'}),
    };
  }

  @override
  void close({bool force = false}) {}

  // ------------------------------------------------------------------- Auth

  ResponseBody _register(Map<String, dynamic> body) {
    final email = (body['email'] as String? ?? '').trim().toLowerCase();
    final password = body['password'] as String? ?? '';

    if (!email.contains('@')) {
      return _validationError('email', 'value is not a valid email address');
    }
    if (password.length < 6) {
      return _validationError(
        'password',
        'String should have at least 6 characters',
      );
    }

    if (_usersByEmail.containsKey(email)) {
      return _json(409, {
        'detail': 'Bu e-posta ile bir hesap zaten var.',
        'error_code': 'email_already_registered',
      });
    }

    final user = _createUser(email: email, password: password, status: 'free');
    return _json(201, _tokenResponse(user));
  }

  ResponseBody _login(Map<String, dynamic> body) {
    final email = (body['email'] as String? ?? '').trim().toLowerCase();
    final password = body['password'] as String? ?? '';
    final user = _usersByEmail[email];

    if (user == null || user.password != password) {
      return _json(401, {
        'detail': 'E-posta veya şifre hatalı.',
        'error_code': 'invalid_credentials',
      });
    }

    // Her girişte yeni anahtar: gerçek sunucu da öyle yapıyor.
    final token = _issueToken(user);
    return _json(200, _tokenResponse(user, token: token));
  }

  ResponseBody _me(RequestOptions options) {
    final user = _authenticate(options);
    if (user == null) return _unauthorized();
    return _json(200, _userJson(user));
  }

  ResponseBody _updateSubscription(
    RequestOptions options,
    Map<String, dynamic> body,
  ) {
    final user = _authenticate(options);
    if (user == null) return _unauthorized();

    final status = body['subscription_status'] as String? ?? '';
    if (!const {'free', 'lifetime_tests', 'ai_pro'}.contains(status)) {
      return _validationError('subscription_status', 'geçersiz değer');
    }

    user.subscriptionStatus = status;
    return _json(200, _userJson(user));
  }

  // ---------------------------------------------------------------- Results

  ResponseBody _createResult(
    RequestOptions options,
    Map<String, dynamic> body,
  ) {
    final user = _authenticate(options);
    if (user == null) return _unauthorized();

    final testId = (body['test_id'] as num?)?.toInt();
    final score = (body['score'] as num?)?.toInt();

    if (testId == null || testId < 1) {
      return _validationError('test_id', 'Input should be greater than 0');
    }
    if (score == null || score < 0 || score > 100) {
      return _validationError(
        'score',
        'Input should be less than or equal to 100',
      );
    }

    final completedAt =
        DateTime.tryParse(body['completed_at'] as String? ?? '') ??
            DateTime.now();

    final result = FakeResult(
      id: _results.length + 1,
      userId: user.id,
      testId: testId,
      score: score,
      completedAt: completedAt,
    );
    _results.add(result);

    return _json(201, {
      'id': result.id,
      'test_id': result.testId,
      'score': result.score,
      'completed_at': result.completedAt.toIso8601String(),
      'passed': result.score >= 70,
    });
  }

  ResponseBody _stats(RequestOptions options) {
    final user = _authenticate(options);
    if (user == null) return _unauthorized();

    final mine = _results.where((item) => item.userId == user.id).toList();

    if (mine.isEmpty) {
      return _json(200, {
        'total_attempts': 0,
        'completed_test_count': 0,
        'average_score': 0,
        'best_score': 0,
        'passed_attempts': 0,
        'last_completed_at': null,
        'per_test': <Map<String, dynamic>>[],
      });
    }

    final scores = mine.map((item) => item.score).toList();
    final testIds = mine.map((item) => item.testId).toSet().toList()..sort();

    return _json(200, {
      'total_attempts': mine.length,
      'completed_test_count': testIds.length,
      'average_score':
          (scores.reduce((a, b) => a + b) / scores.length).round(),
      'best_score': scores.reduce((a, b) => a > b ? a : b),
      'passed_attempts': scores.where((score) => score >= 70).length,
      'last_completed_at': mine
          .map((item) => item.completedAt)
          .reduce((a, b) => a.isAfter(b) ? a : b)
          .toIso8601String(),
      'per_test': [
        for (final testId in testIds) _breakdown(mine, testId),
      ],
    });
  }

  Map<String, dynamic> _breakdown(List<FakeResult> mine, int testId) {
    final forTest = mine.where((item) => item.testId == testId).toList()
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    return {
      'test_id': testId,
      'attempts': forTest.length,
      'best_score':
          forTest.map((item) => item.score).reduce((a, b) => a > b ? a : b),
      'last_score': forTest.last.score,
      'last_completed_at': forTest.last.completedAt.toIso8601String(),
    };
  }

  // --------------------------------------------------------------------- AI

  ResponseBody _ask(RequestOptions options, Map<String, dynamic> body) {
    final user = _authenticate(options);
    if (user == null) return _unauthorized();

    if (user.subscriptionStatus != 'ai_pro') {
      return _json(403, {
        'detail': 'Bu özellik AI Pro paketine dâhildir.',
        'error_code': 'subscription_required',
      });
    }

    final question = (body['question'] as String? ?? '').trim();
    if (question.isEmpty) {
      return _validationError(
        'question',
        'String should have at least 1 character',
      );
    }

    final images = body['images'];
    if (images is List) {
      receivedImages.add(images.whereType<String>().toList());
    }

    if (ollamaDown) {
      return _json(503, {
        'detail': 'Yerel AI servisine (Ollama) ulaşılamıyor. Sunucuda '
            '`ollama serve` çalışıyor mu?',
        'error_code': 'ai_unavailable',
      });
    }

    return _json(200, {
      'answer': aiAnswer,
      'model': images is List && images.isNotEmpty ? 'llava' : aiModel,
      'duration_ms': 1500,
    });
  }

  ResponseBody _aiHealth() {
    return _json(200, {
      'available': !ollamaDown,
      'base_url': 'http://localhost:11434',
      'configured_model': aiModel,
      'configured_vision_model': 'llava',
      'installed_models': ollamaDown ? <String>[] : ['llama3:latest'],
      'model_ready': !ollamaDown,
      'detail': ollamaDown ? 'Ollama\'ya bağlanılamadı.' : null,
    });
  }

  // -------------------------------------------------------------- Yardımcı

  _FakeUser _createUser({
    required String email,
    required String password,
    required String status,
  }) {
    final user = _FakeUser(
      id: _nextUserId++,
      email: email.toLowerCase(),
      password: password,
      subscriptionStatus: status,
      createdAt: DateTime.now(),
    );

    _usersByEmail[user.email] = user;
    _issueToken(user);
    return user;
  }

  String _issueToken(_FakeUser user) {
    final token = 'fake-token-${++_tokenCounter}';
    user.token = token;
    _usersByToken[token] = user;
    return token;
  }

  _FakeUser? _authenticate(RequestOptions options) {
    final header = options.headers['Authorization'];
    if (header is! String || !header.startsWith('Bearer ')) return null;
    return _usersByToken[header.substring(7)];
  }

  Map<String, dynamic> _tokenResponse(_FakeUser user, {String? token}) => {
        'access_token': token ?? user.token,
        'token_type': 'bearer',
        'expires_in': 604800,
        'user': _userJson(user),
      };

  Map<String, dynamic> _userJson(_FakeUser user) => {
        'id': user.id,
        'email': user.email,
        'subscription_status': user.subscriptionStatus,
        'created_at': user.createdAt.toIso8601String(),
      };

  ResponseBody _unauthorized() => _json(401, {
        'detail': 'Bu işlem için giriş yapmanız gerekiyor.',
        'error_code': 'not_authenticated',
      });

  /// FastAPI'nin 422 gövdesini birebir taklit eder.
  ResponseBody _validationError(String field, String message) => _json(422, {
        'detail': [
          {
            'type': 'value_error',
            'loc': ['body', field],
            'msg': message,
          },
        ],
      });

  static Map<String, dynamic> _decodeBody(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String && data.isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    return const {};
  }

  static ResponseBody _json(int status, Map<String, dynamic> body) {
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _FakeUser {
  _FakeUser({
    required this.id,
    required this.email,
    required this.password,
    required this.subscriptionStatus,
    required this.createdAt,
  });

  final int id;
  final String email;
  final String password;
  final DateTime createdAt;

  String subscriptionStatus;
  String token = '';
}

/// Sunucuda saklanan tek bir test sonucu.
class FakeResult {
  const FakeResult({
    required this.id,
    required this.userId,
    required this.testId,
    required this.score,
    required this.completedAt,
  });

  final int id;
  final int userId;
  final int testId;
  final int score;
  final DateTime completedAt;
}

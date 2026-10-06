import '../../../core/network/api_config.dart';
import '../../../core/network/api_service.dart';

/// Sunucudan dönen AI yanıtı.
class AiAnswer {
  const AiAnswer({
    required this.answer,
    required this.model,
    required this.durationMs,
  });

  final String answer;

  /// Yanıtı üreten Ollama modeli (ör. `llama3`, `llava`).
  final String model;

  final int durationMs;

  static AiAnswer fromJson(Map<String, dynamic> json) {
    return AiAnswer(
      answer: (json['answer'] as String? ?? '').trim(),
      model: json['model'] as String? ?? '',
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Ollama sunucusunun durumu.
class AiHealth {
  const AiHealth({
    required this.available,
    required this.modelReady,
    required this.configuredModel,
    this.detail,
  });

  final bool available;
  final bool modelReady;
  final String configuredModel;
  final String? detail;

  /// Soru sorulabilir mi.
  bool get isUsable => available && modelReady;

  static AiHealth fromJson(Map<String, dynamic> json) {
    return AiHealth(
      available: json['available'] as bool? ?? false,
      modelReady: json['model_ready'] as bool? ?? false,
      configuredModel: json['configured_model'] as String? ?? '',
      detail: json['detail'] as String?,
    );
  }
}

/// `/ai` uçlarının ince sarmalayıcısı.
class AiApi {
  const AiApi(this._api);

  final ApiService _api;

  /// Soruyu (ve varsa fotoğrafları) sunucudaki Llama 3 modeline iletir.
  Future<AiAnswer> ask({
    required String question,
    String? context,
    List<String>? images,
  }) async {
    final json = await _api.postJson(
      '/ai/ask',
      body: {
        'question': question,
        if (context != null && context.isNotEmpty) 'context': context,
        if (images != null && images.isNotEmpty) 'images': images,
      },
      // Yerel model yanıtı yavaş üretebilir; genel süreden uzun bekliyoruz.
      receiveTimeout: ApiConfig.aiReceiveTimeout,
    );

    return AiAnswer.fromJson(json);
  }

  Future<AiHealth> health() async {
    return AiHealth.fromJson(await _api.getJson('/ai/health'));
  }
}

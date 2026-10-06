import '../domain/ai_message.dart';
import 'ai_api.dart';

/// AI koç sohbetinin veri kaynağı.
///
/// Yanıtlar artık cihazda üretilmiyor: soru sunucudaki `/ai/ask` ucuna
/// gidiyor, orada yerel Ollama (Llama 3) modeline iletiliyor.
class AiCoachService {
  const AiCoachService(this._api);

  final AiApi _api;

  /// Sohbet ilk açıldığında gösterilen karşılama.
  static const String greeting =
      'Merhaba! Ben senin AI ehliyet koçunum. Bir araç parçasının fotoğrafını '
      'yükleyebilir ya da aklına takılanı yazabilirsin. Örnek: '
      '"Alternatör nedir?"';

  /// Kullanıcıya hızlı başlangıç için sunulan sorular.
  static const List<String> suggestions = [
    'Alternatör nedir?',
    'Debriyaj ne işe yarar?',
    'Koma pozisyonu nasıl verilir?',
    'Takip mesafesi nasıl hesaplanır?',
  ];

  /// Soruyu sunucuya iletir ve koç mesajını üretir.
  ///
  /// Hata durumunda [ApiException] yukarıya fırlatılır; arayüz onu
  /// kullanıcıya uygun uyarıya çevirir.
  Future<AiMessage> reply({
    required String prompt,
    String? context,
    List<String>? images,
  }) async {
    final answer = await _api.ask(
      question: prompt,
      context: context,
      images: images,
    );

    return AiMessage(
      id: 'coach-${DateTime.now().microsecondsSinceEpoch}',
      author: AiMessageAuthor.coach,
      text: answer.answer,
      canPlayAudio: answer.answer.isNotEmpty,
      model: answer.model,
    );
  }

  /// Ollama'nın hazır olup olmadığını sorar (sekme açılışında bilgilendirme).
  Future<AiHealth> health() => _api.health();
}

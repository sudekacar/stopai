/// Mesajı kimin yazdığı.
enum AiMessageAuthor { user, coach }

/// Sohbete eklenen görsel.
class AiAttachment {
  const AiAttachment({
    required this.fileName,
    required this.source,
    required this.base64Data,
  });

  final String fileName;

  /// 'Kamera' veya 'Galeri'.
  final String source;

  /// Sunucuya (ve oradan Ollama'ya) gönderilen base64 içerik.
  /// Data URL öneki taşımaz.
  final String base64Data;
}

/// Sohbetteki tek bir mesaj.
class AiMessage {
  const AiMessage({
    required this.id,
    required this.author,
    required this.text,
    this.attachment,
    this.canPlayAudio = false,
    this.model,
    this.isError = false,
    this.errorCode,
  });

  final String id;
  final AiMessageAuthor author;
  final String text;
  final AiAttachment? attachment;

  /// Koç mesajları sesli anlatılabilir (AI Pro paketinin sesli özelliği).
  final bool canPlayAudio;

  /// Yanıtı üreten model; hata mesajlarında ve kullanıcı mesajlarında boş.
  final String? model;

  /// Sunucudan hata döndüğünde gösterilen uyarı mesajı.
  final bool isError;

  /// Hatanın backend'deki `error_code` değeri; arayüz buna göre eylem sunar
  /// (ör. paket gerekiyorsa paywall'a götürmek).
  final String? errorCode;

  bool get isUser => author == AiMessageAuthor.user;
}

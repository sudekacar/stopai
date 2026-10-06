import 'package:flutter/foundation.dart';

import '../../../core/safe_notifier.dart';

import '../../../core/network/api_exception.dart';
import '../data/ai_api.dart';
import '../data/ai_coach_service.dart';
import '../data/image_picker_service.dart';
import '../domain/ai_message.dart';

/// AI sohbetinin durumu.
class AiCoachController extends ChangeNotifier with SafeNotifier {
  AiCoachController(this._service, this._imagePicker) {
    _messages.add(
      const AiMessage(
        id: 'coach-greeting',
        author: AiMessageAuthor.coach,
        text: AiCoachService.greeting,
      ),
    );
  }

  final AiCoachService _service;
  final ImagePickerService _imagePicker;
  final List<AiMessage> _messages = [];

  bool _isTyping = false;
  AiAttachment? _pendingAttachment;
  AiHealth? _health;
  String? _speakingMessageId;

  /// Eskiden yeniye sıralı mesajlar.
  List<AiMessage> get messages => List.unmodifiable(_messages);

  /// Koç yanıt üretiyor mu.
  bool get isTyping => _isTyping;

  /// Gönderilmeyi bekleyen görsel.
  AiAttachment? get pendingAttachment => _pendingAttachment;

  /// Ollama durumu; sorgulanmadıysa `null`.
  AiHealth? get health => _health;

  String? get speakingMessageId => _speakingMessageId;

  List<String> get suggestions => AiCoachService.suggestions;

  /// Sekme açılırken Ollama'nın hazır olup olmadığını öğrenir.
  ///
  /// Hata fırlatmaz: sunucuya ulaşılamıyorsa durum bilinmiyor kabul edilir.
  Future<void> checkHealth() async {
    try {
      _health = await _service.health();
    } on ApiException {
      _health = null;
    }
    safeNotifyListeners();
  }

  /// Kamera/galeriden fotoğraf seçer ve sohbete iliştirir.
  Future<void> attachPhoto({required bool fromCamera}) async {
    final attachment = await _imagePicker.pick(fromCamera: fromCamera);
    if (attachment == null) return;

    _pendingAttachment = attachment;
    safeNotifyListeners();
  }

  void removeAttachment() {
    if (_pendingAttachment == null) return;
    _pendingAttachment = null;
    safeNotifyListeners();
  }

  /// Mesajı sunucuya gönderir ve koçun yanıtını bekler.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    final attachment = _pendingAttachment;

    if (_isTyping) return;
    if (trimmed.isEmpty && attachment == null) return;

    final question = trimmed.isEmpty ? 'Bu parça nedir?' : trimmed;

    _messages.add(
      AiMessage(
        id: 'user-${DateTime.now().microsecondsSinceEpoch}',
        author: AiMessageAuthor.user,
        text: question,
        attachment: attachment,
      ),
    );
    _pendingAttachment = null;
    _isTyping = true;
    safeNotifyListeners();

    try {
      _messages.add(
        await _service.reply(
          prompt: question,
          images: attachment == null ? null : [attachment.base64Data],
        ),
      );
    } on ApiException catch (error) {
      _messages.add(_errorMessage(error));
    } finally {
      _isTyping = false;
      safeNotifyListeners();
    }
  }

  /// Son kullanıcı sorusunu yeniden gönderir ("Tekrar Dene").
  Future<void> retryLastQuestion() async {
    if (_isTyping) return;

    final lastUserMessage =
        _messages.lastWhere((message) => message.isUser, orElse: _noMessage);
    if (lastUserMessage.id.isEmpty) return;

    // Başarısız denemeye ait hata baloncuğunu ve soruyu listeden çıkarıp
    // akışı baştan kuruyoruz; sohbet tekrar eden kayıtlarla şişmesin.
    while (_messages.isNotEmpty && _messages.last.id != lastUserMessage.id) {
      _messages.removeLast();
    }
    if (_messages.isNotEmpty) _messages.removeLast();

    _pendingAttachment = lastUserMessage.attachment;
    await send(lastUserMessage.text);
  }

  /// Sesli anlatım. `flutter_tts` bağlanana kadar yalnızca durumu tutar.
  void toggleSpeech(String messageId) {
    // TODO(ai): `flutter_tts` ile metni sese çevir; şimdilik yer tutucu.
    _speakingMessageId = _speakingMessageId == messageId ? null : messageId;
    safeNotifyListeners();
  }

  static AiMessage _noMessage() => const AiMessage(
        id: '',
        author: AiMessageAuthor.user,
        text: '',
      );

  /// Sunucu hatasını sohbette gösterilecek uyarıya çevirir.
  AiMessage _errorMessage(ApiException error) {
    return AiMessage(
      id: 'error-${DateTime.now().microsecondsSinceEpoch}',
      author: AiMessageAuthor.coach,
      text: _friendlyText(error),
      isError: true,
      errorCode: error.errorCode,
    );
  }

  static String _friendlyText(ApiException error) {
    if (error.requiresSubscription) {
      return 'AI koç, AI Pro paketine dâhildir. Paketi alarak fotoğraf '
          'yükleyebilir ve sınırsız soru sorabilirsin.';
    }

    if (error.errorCode == ApiErrorCode.aiUnavailable) {
      return 'AI koç şu an kapalı. Sunucuda yerel model (Ollama) '
          'çalışmıyor; birazdan tekrar dene.';
    }

    if (error.errorCode == ApiErrorCode.aiModelMissing) {
      return 'Sunucuda AI modeli yüklü değil. Yönetici modeli kurduktan '
          'sonra tekrar deneyebilirsin.';
    }

    if (error.errorCode == ApiErrorCode.aiTimeout) {
      return 'Model yanıt vermesi çok uzun sürdü. Soruyu biraz '
          'kısaltıp tekrar dener misin?';
    }

    return error.message;
  }
}

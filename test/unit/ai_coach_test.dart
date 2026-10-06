import 'package:flutter_test/flutter_test.dart';
import 'package:stop_ai_ehliyet_kocu/core/network/api_exception.dart';
import 'package:stop_ai_ehliyet_kocu/core/storage/token_store.dart';
import 'package:stop_ai_ehliyet_kocu/features/ai/data/ai_api.dart';
import 'package:stop_ai_ehliyet_kocu/features/ai/data/ai_coach_service.dart';
import 'package:stop_ai_ehliyet_kocu/features/ai/presentation/ai_coach_controller.dart';

import '../helpers/fake_backend.dart';
import '../helpers/pump_app.dart';

void main() {
  late FakeBackend backend;
  late AiCoachService service;
  late FakeImagePicker picker;
  late AiCoachController controller;

  setUp(() {
    backend = FakeBackend()
      ..seedUser(
        email: testEmail,
        password: testPassword,
        subscriptionStatus: 'ai_pro',
      );

    final api = createTestApiService(
      backend,
      tokenStore: InMemoryTokenStore('fake-token-1'),
    );
    service = AiCoachService(AiApi(api));
    picker = FakeImagePicker();
    controller = AiCoachController(service, picker);
    addTearDown(controller.dispose);
  });

  group('AiCoachService', () {
    test('soru sunucuya iletilir ve yanıt döner', () async {
      final message = await service.reply(prompt: 'Alternatör nedir?');

      expect(message.text, contains('aküyü şarj'));
      expect(message.model, 'llama3');
      expect(message.canPlayAudio, isTrue);

      final request = backend.requests.last;
      expect(request.path, endsWith('/ai/ask'));
      expect((request.data as Map)['question'], 'Alternatör nedir?');
    });

    test('görsel gönderildiğinde images alanı doldurulur', () async {
      final message = await service.reply(
        prompt: 'Bu parça nedir?',
        images: const ['QUJD'],
      );

      expect(backend.receivedImages.single, ['QUJD']);
      // Sunucu görsel varken görme modeline geçtiğini bildirir.
      expect(message.model, 'llava');
    });

    test('Ollama kapalıysa hata fırlatılır', () async {
      backend.ollamaDown = true;

      await expectLater(
        service.reply(prompt: 'Alternatör nedir?'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isAiUnavailable, 'isAiUnavailable', isTrue),
        ),
      );
    });

    test('sağlık kontrolü modelin hazır olup olmadığını bildirir', () async {
      expect((await service.health()).isUsable, isTrue);

      backend.ollamaDown = true;
      final health = await service.health();
      expect(health.isUsable, isFalse);
      expect(health.detail, isNotNull);
    });
  });

  group('AiCoachController', () {
    test('karşılama mesajıyla başlar', () {
      expect(controller.messages, hasLength(1));
      expect(controller.messages.first.isUser, isFalse);
      expect(controller.isTyping, isFalse);
    });

    test('mesaj gönderince kullanıcı ve koç mesajı eklenir', () async {
      await controller.send('Debriyaj ne işe yarar?');

      expect(controller.messages, hasLength(3));
      expect(controller.messages[1].isUser, isTrue);
      expect(controller.messages[2].isUser, isFalse);
      expect(controller.messages[2].isError, isFalse);
      expect(controller.isTyping, isFalse);
    });

    test('boş mesaj gönderilmez', () async {
      await controller.send('   ');

      expect(controller.messages, hasLength(1));
      expect(backend.requests, isEmpty);
    });

    test('fotoğraf eklenip metin yazılmadan gönderilebilir', () async {
      await controller.attachPhoto(fromCamera: false);
      expect(controller.pendingAttachment, isNotNull);
      expect(picker.lastFromCamera, isFalse);

      await controller.send('');

      expect(controller.pendingAttachment, isNull);
      expect(controller.messages[1].text, 'Bu parça nedir?');
      expect(controller.messages[1].attachment, isNotNull);
      expect(backend.receivedImages.single, ['QUJD']);
    });

    test('kullanıcı fotoğraf seçmekten vazgeçerse ek oluşmaz', () async {
      picker.attachment = null;

      await controller.attachPhoto(fromCamera: true);

      expect(controller.pendingAttachment, isNull);
    });

    test('paket yoksa hata baloncuğu paket koduyla eklenir', () async {
      backend.seedUser(
        email: 'ucretsiz@stopkoc.com',
        password: testPassword,
      );
      final api = createTestApiService(
        backend,
        // İkinci kullanıcının anahtarı.
        tokenStore: InMemoryTokenStore('fake-token-2'),
      );
      final freeController = AiCoachController(
        AiCoachService(AiApi(api)),
        FakeImagePicker(),
      );
      addTearDown(freeController.dispose);

      await freeController.send('Alternatör nedir?');

      final last = freeController.messages.last;
      expect(last.isError, isTrue);
      expect(last.errorCode, ApiErrorCode.subscriptionRequired);
      expect(last.text, contains('AI Pro'));
    });

    test('Ollama kapalıysa anlaşılır bir uyarı gösterilir', () async {
      backend.ollamaDown = true;

      await controller.send('Alternatör nedir?');

      final last = controller.messages.last;
      expect(last.isError, isTrue);
      expect(last.errorCode, ApiErrorCode.aiUnavailable);
      expect(last.text, contains('AI koç şu an kapalı'));
    });

    test('ağ hatasında sunucu mesajı gösterilir', () async {
      backend.offline = true;

      await controller.send('Alternatör nedir?');

      final last = controller.messages.last;
      expect(last.isError, isTrue);
      expect(last.text, contains('Sunucuya ulaşılamıyor'));
    });

    test('tekrar deneme başarısız soruyu yeniden gönderir', () async {
      backend.ollamaDown = true;
      await controller.send('Alternatör nedir?');
      expect(controller.messages.last.isError, isTrue);

      backend.ollamaDown = false;
      await controller.retryLastQuestion();

      final last = controller.messages.last;
      expect(last.isError, isFalse);
      expect(last.text, contains('aküyü şarj'));
      // Soru tekrarlanmadı: kullanıcı mesajı + yanıt + karşılama = 3
      expect(controller.messages, hasLength(3));
    });

    test('tekrar deneme fotoğrafı da yeniden gönderir', () async {
      backend.ollamaDown = true;
      await controller.attachPhoto(fromCamera: true);
      await controller.send('Bu parça nedir?');

      backend.ollamaDown = false;
      await controller.retryLastQuestion();

      expect(controller.messages.last.isError, isFalse);
      expect(backend.receivedImages, hasLength(2));
    });

    test('sağlık durumu sorgulanabilir', () async {
      await controller.checkHealth();
      expect(controller.health?.isUsable, isTrue);

      backend.offline = true;
      await controller.checkHealth();
      // Sunucuya ulaşılamıyorsa durum bilinmiyor kabul edilir.
      expect(controller.health, isNull);
    });

    test('sesli anlatım aç/kapa tek mesajda tutulur', () async {
      await controller.send('Buji nedir?');
      final coachMessageId = controller.messages.last.id;

      controller.toggleSpeech(coachMessageId);
      expect(controller.speakingMessageId, coachMessageId);

      controller.toggleSpeech(coachMessageId);
      expect(controller.speakingMessageId, isNull);
    });
  });
}

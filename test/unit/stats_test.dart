import 'package:flutter_test/flutter_test.dart';
import 'package:stop_ai_ehliyet_kocu/core/storage/key_value_store.dart';
import 'package:stop_ai_ehliyet_kocu/core/storage/token_store.dart';
import 'package:stop_ai_ehliyet_kocu/features/profile/data/results_api.dart';
import 'package:stop_ai_ehliyet_kocu/features/profile/data/stats_repository.dart';
import 'package:stop_ai_ehliyet_kocu/features/profile/domain/quiz_stats.dart';
import 'package:stop_ai_ehliyet_kocu/features/profile/domain/test_attempt.dart';
import 'package:stop_ai_ehliyet_kocu/features/profile/presentation/stats_controller.dart';
import 'package:stop_ai_ehliyet_kocu/features/quiz/domain/question.dart';

import '../helpers/fake_backend.dart';
import '../helpers/pump_app.dart';

TestAttempt attempt({
  required int testNumber,
  required int correct,
  int total = 10,
  DateTime? completedAt,
  Map<QuestionCategory, CategoryScore>? categories,
}) {
  return TestAttempt(
    testNumber: testNumber,
    correctCount: correct,
    questionCount: total,
    completedAt: completedAt ?? DateTime(2026, 9, 25, 14, 30),
    categoryScores: categories ??
        {QuestionCategory.trafik: CategoryScore(correct: correct, total: total)},
  );
}

void main() {
  group('TestAttempt', () {
    test('başarı yüzdesi ve geçme durumu', () {
      expect(attempt(testNumber: 1, correct: 7).successPercentage, 70);
      expect(attempt(testNumber: 1, correct: 7).passed, isTrue);
      expect(attempt(testNumber: 1, correct: 6).passed, isFalse);
      expect(attempt(testNumber: 1, correct: 6).wrongCount, 4);
    });

    test('JSON dönüşümü kategori kırılımını korur', () {
      final original = attempt(
        testNumber: 3,
        correct: 8,
        categories: {
          QuestionCategory.trafik: const CategoryScore(correct: 5, total: 6),
          QuestionCategory.ilkYardim: const CategoryScore(correct: 3, total: 4),
        },
      );

      final restored = TestAttempt.fromJson(original.toJson());

      expect(restored.testNumber, 3);
      expect(restored.categoryScores[QuestionCategory.trafik]?.correct, 5);
      expect(restored.categoryScores[QuestionCategory.ilkYardim]?.total, 4);
    });
  });

  group('QuizStats', () {
    test('kategori toplamları birleştirilir ve en zayıf konu bulunur', () {
      final stats = QuizStats([
        attempt(
          testNumber: 1,
          correct: 6,
          categories: {
            QuestionCategory.trafik: const CategoryScore(correct: 5, total: 5),
            QuestionCategory.motor: const CategoryScore(correct: 1, total: 5),
          },
        ),
        attempt(
          testNumber: 2,
          correct: 6,
          categories: {
            QuestionCategory.trafik: const CategoryScore(correct: 4, total: 5),
            QuestionCategory.motor: const CategoryScore(correct: 2, total: 5),
          },
        ),
      ]);

      expect(stats.byCategory[QuestionCategory.trafik]?.correct, 9);
      expect(stats.byCategory[QuestionCategory.motor]?.percentage, 30);
      expect(stats.weakestCategory, QuestionCategory.motor);
    });

    test('aynı test iki kez çözülse bir kez sayılır', () {
      final stats = QuizStats([
        attempt(testNumber: 1, correct: 6),
        attempt(testNumber: 1, correct: 9),
        attempt(testNumber: 2, correct: 8),
      ]);

      expect(stats.attemptCount, 3);
      expect(stats.completedTestCount, 2);
      expect(stats.bestSuccessPercentage, 90);
    });
  });

  group('StatsRepository', () {
    late FakeBackend backend;
    late InMemoryKeyValueStore store;
    late StatsRepository repository;

    Future<void> signIn() async {
      backend.seedUser(email: testEmail, password: testPassword);
    }

    setUp(() async {
      backend = FakeBackend();
      store = InMemoryKeyValueStore();
      await signIn();

      // Sunucuya kimlik göstermek için hazır bir anahtar kullanıyoruz.
      final api = createTestApiService(
        backend,
        tokenStore: InMemoryTokenStore('fake-token-1'),
      );
      repository = StatsRepository(ResultsApi(api), store)
        ..setUser(testEmail);
    });

    test('sonuç hem cihaza hem sunucuya yazılır', () async {
      final result = await repository.saveAttempt(
        attempt(testNumber: 1, correct: 9),
      );

      expect(result.synced, isTrue);
      expect(result.local.attemptCount, 1);
      expect(backend.resultCount, 1);
      expect(backend.results.single.testId, 1);
      expect(backend.results.single.score, 90);
    });

    test('sunucuya ulaşılamazsa sonuç kuyruğa alınır', () async {
      backend.offline = true;

      final result = await repository.saveAttempt(
        attempt(testNumber: 2, correct: 8),
      );

      expect(result.synced, isFalse);
      // Skor kaybolmaz: cihazda ve kuyrukta duruyor.
      expect(result.local.attemptCount, 1);
      expect(repository.pendingCount, 1);
      expect(backend.resultCount, 0);
    });

    test('bağlantı gelince kuyruk gönderilir', () async {
      backend.offline = true;
      await repository.saveAttempt(attempt(testNumber: 2, correct: 8));
      await repository.saveAttempt(attempt(testNumber: 3, correct: 7));
      expect(repository.pendingCount, 2);

      backend.offline = false;
      final sent = await repository.syncPending();

      expect(sent, 2);
      expect(repository.pendingCount, 0);
      expect(backend.resultCount, 2);
    });

    test('kuyruk hâlâ çevrimdışıysa korunur', () async {
      backend.offline = true;
      await repository.saveAttempt(attempt(testNumber: 2, correct: 8));

      final sent = await repository.syncPending();

      expect(sent, 0);
      expect(repository.pendingCount, 1);
    });

    test('sunucu istatistikleri okunur', () async {
      await repository.saveAttempt(
        attempt(
          testNumber: 1,
          correct: 5,
          completedAt: DateTime.utc(2026, 9, 20),
        ),
      );
      await repository.saveAttempt(
        attempt(
          testNumber: 1,
          correct: 9,
          completedAt: DateTime.utc(2026, 9, 22),
        ),
      );
      await repository.saveAttempt(
        attempt(
          testNumber: 2,
          correct: 8,
          completedAt: DateTime.utc(2026, 9, 24),
        ),
      );

      final remote = await repository.fetchRemote();

      expect(remote.totalAttempts, 3);
      expect(remote.completedTestCount, 2);
      expect(remote.averageScore, 73); // (50+90+80)/3 = 73.33 -> 73
      expect(remote.bestScore, 90);
      expect(remote.passedAttempts, 2);

      final firstTest = remote.breakdownFor(1)!;
      expect(firstTest.attempts, 2);
      expect(firstTest.bestScore, 90);
      expect(firstTest.lastScore, 90);
    });

    test('yerel kayıtlar kullanıcıya özel', () async {
      await repository.saveAttempt(attempt(testNumber: 1, correct: 9));

      repository.setUser('baska@stopkoc.com');
      expect(repository.loadLocal().isEmpty, isTrue);
    });
  });

  group('StatsController', () {
    late FakeBackend backend;
    late StatsController controller;

    setUp(() {
      backend = FakeBackend()
        ..seedUser(email: testEmail, password: testPassword);

      final api = createTestApiService(
        backend,
        tokenStore: InMemoryTokenStore('fake-token-1'),
      );
      controller = StatsController(
        StatsRepository(ResultsApi(api), InMemoryKeyValueStore()),
      );
      addTearDown(controller.dispose);
    });

    test('yükleme sunucudan veriyi çeker', () async {
      await controller.loadFor(testEmail);

      expect(controller.hasRemoteData, isTrue);
      expect(controller.isEmpty, isTrue);
      expect(controller.completedTestCount, 0);
    });

    test('kaydedilen sonuç sunucu özetine yansır', () async {
      await controller.loadFor(testEmail);

      await controller.recordAttempt(attempt(testNumber: 4, correct: 9));

      expect(controller.totalAttempts, 1);
      expect(controller.completedTestCount, 1);
      expect(controller.bestScore, 90);
      expect(controller.bestScoreFor(4), 90);
      expect(controller.bestScoreFor(7), isNull);
    });

    test('sunucu erişilemezse yerel veriyle devam eder', () async {
      await controller.loadFor(testEmail);
      backend.offline = true;

      await controller.recordAttempt(attempt(testNumber: 5, correct: 6));
      await controller.refresh();

      expect(controller.errorMessage, isNotNull);
      // Yerel kayıt sayesinde profil boş görünmez.
      expect(controller.local.attemptCount, 1);
      expect(controller.pendingCount, 1);
      expect(controller.bestScoreFor(5), 60);
    });

    test('oturum kapanınca istatistikler temizlenir', () async {
      await controller.loadFor(testEmail);
      await controller.recordAttempt(attempt(testNumber: 1, correct: 9));

      await controller.loadFor(null);

      expect(controller.isEmpty, isTrue);
      expect(controller.hasRemoteData, isFalse);
    });
  });
}

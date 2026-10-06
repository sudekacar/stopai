import 'package:flutter_test/flutter_test.dart';
import 'package:stop_ai_ehliyet_kocu/core/ads/ad_config.dart';
import 'package:stop_ai_ehliyet_kocu/core/ads/ad_manager.dart';
import 'package:stop_ai_ehliyet_kocu/features/profile/domain/test_attempt.dart';
import 'package:stop_ai_ehliyet_kocu/features/quiz/domain/answer_state.dart';
import 'package:stop_ai_ehliyet_kocu/features/quiz/presentation/quiz_controller.dart';
import 'package:stop_ai_ehliyet_kocu/features/tests/data/test_catalog.dart';

void main() {
  late AdManager ads;
  late QuizController controller;
  TestAttempt? recordedAttempt;

  setUp(() {
    ads = AdManager();
    recordedAttempt = null;
    controller = QuizController(
      bundle: TestCatalog.byNumber(1),
      adManager: ads,
      onCompleted: (attempt) => recordedAttempt = attempt,
    );
  });

  tearDown(() {
    controller.dispose();
    ads.dispose();
  });

  /// O anki sorunun doğru şıkkını seçer.
  void answerCorrectly() =>
      controller.selectAnswer(controller.currentQuestion.correctIndex);

  /// O anki sorunun ilk yanlış şıkkını seçer.
  void answerWrongly() {
    final question = controller.currentQuestion;
    final wrongIndex =
        (question.correctIndex + 1) % question.options.length;
    controller.selectAnswer(wrongIndex);
  }

  test('test 5 soruluk reklam aralığından uzun', () {
    expect(
      controller.questionCount,
      greaterThan(AdConfig.interstitialQuestionInterval),
    );
  });

  test('doğru cevap yeşil, diğer şıklar soluk', () {
    final correctIndex = controller.currentQuestion.correctIndex;
    answerCorrectly();

    expect(controller.feedback, AnswerFeedback.correct);
    expect(controller.correctCount, 1);
    expect(controller.wrongCount, 0);
    expect(
      controller.optionState(correctIndex),
      AnswerOptionState.selectedCorrect,
    );

    final otherIndex =
        (correctIndex + 1) % controller.currentQuestion.options.length;
    expect(controller.optionState(otherIndex), AnswerOptionState.dimmed);
  });

  test('yanlış cevap mavi, doğru şık yeşil olarak açığa çıkar', () {
    final question = controller.currentQuestion;
    final wrongIndex = (question.correctIndex + 1) % question.options.length;

    answerWrongly();

    expect(controller.feedback, AnswerFeedback.wrong);
    expect(controller.wrongCount, 1);
    expect(controller.optionState(wrongIndex), AnswerOptionState.selectedWrong);
    expect(
      controller.optionState(question.correctIndex),
      AnswerOptionState.revealedCorrect,
    );
  });

  test('aynı soruda ikinci seçim yok sayılır', () {
    final correctIndex = controller.currentQuestion.correctIndex;
    answerCorrectly();
    controller.selectAnswer((correctIndex + 1) % 4);

    expect(controller.selectedIndex, correctIndex);
    expect(controller.correctCount, 1);
  });

  test('cevap verilmeden sonraki soruya geçilemez', () {
    controller.goToNextQuestion();

    expect(controller.currentIndex, 0);
    expect(ads.completedQuestionCount, 0);
  });

  test('geçiş reklamı her 5 soruda bir tetiklenir', () {
    for (var i = 0; i < 5; i++) {
      expect(ads.interstitialTriggerCount, 0, reason: '${i + 1}. soru');
      answerCorrectly();
      controller.goToNextQuestion();
    }

    expect(ads.completedQuestionCount, 5);
    expect(ads.interstitialTriggerCount, 1);

    // 6-9. sorularda tetiklenmez, 10. soruda ikinci kez tetiklenir.
    for (var i = 5; i < 9; i++) {
      answerCorrectly();
      controller.goToNextQuestion();
      expect(ads.interstitialTriggerCount, 1, reason: '${i + 1}. soru');
    }

    answerCorrectly();
    controller.goToNextQuestion();
    expect(ads.interstitialTriggerCount, 2);
  });

  test('reklamlar kapalıyken sayaç ilerler ama reklam çıkmaz', () {
    ads.setAdsEnabled(false);

    for (var i = 0; i < 5; i++) {
      answerCorrectly();
      controller.goToNextQuestion();
    }

    expect(ads.completedQuestionCount, 5);
    expect(ads.interstitialTriggerCount, 0);
  });

  test('son soru geçilince test biter ve sonuç kaydedilir', () {
    for (var i = 0; i < controller.questionCount; i++) {
      answerCorrectly();
      controller.goToNextQuestion();
    }

    expect(controller.isFinished, isTrue);
    expect(controller.successPercentage, 100);

    expect(recordedAttempt, isNotNull);
    expect(recordedAttempt!.testNumber, 1);
    expect(recordedAttempt!.correctCount, controller.questionCount);
    expect(recordedAttempt!.passed, isTrue);
  });

  test('kayıt edilen sonuç kategori kırılımını taşır', () {
    answerWrongly();
    controller.goToNextQuestion();
    for (var i = 1; i < controller.questionCount; i++) {
      answerCorrectly();
      controller.goToNextQuestion();
    }

    final attempt = recordedAttempt!;
    final totalFromCategories = attempt.categoryScores.values
        .fold<int>(0, (sum, score) => sum + score.total);

    expect(totalFromCategories, controller.questionCount);
    expect(attempt.wrongCount, 1);
  });

  test('restart sayaçları ve reklam sayacını sıfırlar', () {
    answerCorrectly();
    controller.goToNextQuestion();
    controller.restart();

    expect(controller.currentIndex, 0);
    expect(controller.selectedIndex, isNull);
    expect(controller.correctCount, 0);
    expect(controller.isFinished, isFalse);
    expect(controller.hasStarted, isFalse);
    expect(ads.completedQuestionCount, 0);
  });
}

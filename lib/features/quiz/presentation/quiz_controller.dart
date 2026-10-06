import 'package:flutter/foundation.dart';

import '../../../core/ads/ad_manager.dart';
import '../../profile/domain/test_attempt.dart';
import '../../tests/domain/test_bundle.dart';
import '../domain/answer_state.dart';
import '../domain/question.dart';

/// Tek bir testin akışını yönetir: hangi soruda olunduğu, verilen cevaplar,
/// skor ve şıkların görsel durumu.
///
/// Arayüzden bağımsız olduğu için widget testi olmadan da test edilebilir.
class QuizController extends ChangeNotifier {
  QuizController({
    required this.bundle,
    required this.adManager,
    this.onCompleted,
  }) : assert(bundle.questions.isNotEmpty, 'Test boş olamaz');

  final TestBundle bundle;
  final AdManager adManager;

  /// Test bittiğinde sonucu kaydetmek için çağrılır.
  final void Function(TestAttempt attempt)? onCompleted;

  /// Soru sırasına göre seçilen şık; cevaplanmamış sorularda `null`.
  late final List<int?> _answers = List<int?>.filled(questionCount, null);

  int _currentIndex = 0;
  bool _isFinished = false;

  List<Question> get questions => bundle.questions;
  int get questionCount => bundle.questionCount;
  int get currentIndex => _currentIndex;

  /// 1 tabanlı soru numarası (arayüzde "3/10" gibi göstermek için).
  int get currentQuestionNumber => _currentIndex + 1;

  Question get currentQuestion => questions[_currentIndex];

  int? get selectedIndex => _answers[_currentIndex];
  bool get isAnswered => selectedIndex != null;
  bool get isLastQuestion => _currentIndex == questionCount - 1;
  bool get isFinished => _isFinished;

  /// Kullanıcı testin başında hiç cevap vermediyse çıkışta onay sormayız.
  bool get hasStarted => answeredCount > 0;

  int get answeredCount => _answers.where((answer) => answer != null).length;

  int get correctCount {
    var total = 0;
    for (var i = 0; i < questionCount; i++) {
      final answer = _answers[i];
      if (answer != null && questions[i].isCorrect(answer)) total++;
    }
    return total;
  }

  int get wrongCount => answeredCount - correctCount;

  double get progressRatio => answeredCount / questionCount;

  /// Yüzde olarak başarı oranı (0-100). Cevaplanan sorular üzerinden.
  int get successPercentage =>
      answeredCount == 0 ? 0 : ((correctCount / answeredCount) * 100).round();

  AnswerFeedback get feedback {
    final selected = selectedIndex;
    if (selected == null) return AnswerFeedback.none;
    return currentQuestion.isCorrect(selected)
        ? AnswerFeedback.correct
        : AnswerFeedback.wrong;
  }

  /// Verilen şıkkın o anki görsel durumu.
  AnswerOptionState optionState(int optionIndex) {
    final selected = selectedIndex;
    if (selected == null) return AnswerOptionState.idle;

    final isSelected = optionIndex == selected;
    final isCorrect = currentQuestion.isCorrect(optionIndex);

    if (isSelected && isCorrect) return AnswerOptionState.selectedCorrect;
    if (isSelected) return AnswerOptionState.selectedWrong;
    if (isCorrect) return AnswerOptionState.revealedCorrect;
    return AnswerOptionState.dimmed;
  }

  /// Bir şıkkı seçer. Aynı soruda ikinci seçim yok sayılır.
  void selectAnswer(int optionIndex) {
    if (isAnswered || _isFinished) return;

    _answers[_currentIndex] = optionIndex;
    notifyListeners();
  }

  /// Sonraki soruya geçer; son soruda testi bitirir.
  ///
  /// Reklam sayacı burada ilerletilir: soru cevaplanıp geçildiğinde sayaç artar
  /// ve `AdConfig.interstitialQuestionInterval` kadar soruda bir
  /// `interstitialAdTrigger()` tetiklenir.
  void goToNextQuestion() {
    if (!isAnswered || _isFinished) return;

    adManager.registerQuestionCompleted();

    if (isLastQuestion) {
      _isFinished = true;
      onCompleted?.call(buildAttempt());
    } else {
      _currentIndex++;
    }
    notifyListeners();
  }

  /// Testi baştan başlatır.
  void restart() {
    _answers.fillRange(0, _answers.length, null);
    _currentIndex = 0;
    _isFinished = false;
    adManager.resetQuestionCounter();
    notifyListeners();
  }

  /// Sonucu istatistiklere yazılabilir bir kayda dönüştürür.
  TestAttempt buildAttempt() {
    final scores = <QuestionCategory, CategoryScore>{};

    for (var i = 0; i < questionCount; i++) {
      final question = questions[i];
      final answer = _answers[i];
      final existing = scores[question.category] ??
          const CategoryScore(correct: 0, total: 0);

      scores[question.category] = CategoryScore(
        correct:
            existing.correct + (answer != null && question.isCorrect(answer) ? 1 : 0),
        total: existing.total + 1,
      );
    }

    return TestAttempt(
      testNumber: bundle.number,
      correctCount: correctCount,
      questionCount: questionCount,
      completedAt: DateTime.now(),
      categoryScores: scores,
    );
  }
}

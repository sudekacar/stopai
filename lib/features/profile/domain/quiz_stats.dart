import '../../quiz/domain/question.dart';
import 'test_attempt.dart';

/// Profil ekranında gösterilen toplu istatistikler.
class QuizStats {
  const QuizStats(this.attempts);

  static const QuizStats empty = QuizStats([]);

  /// En yeniden en eskiye sıralı denemeler.
  final List<TestAttempt> attempts;

  bool get isEmpty => attempts.isEmpty;

  /// Kaç farklı test tamamlandı (aynı test tekrar çözülse de bir kez sayılır).
  int get completedTestCount =>
      attempts.map((attempt) => attempt.testNumber).toSet().length;

  int get attemptCount => attempts.length;

  int get totalQuestions =>
      attempts.fold(0, (sum, attempt) => sum + attempt.questionCount);

  int get totalCorrect =>
      attempts.fold(0, (sum, attempt) => sum + attempt.correctCount);

  int get totalWrong => totalQuestions - totalCorrect;

  /// Tüm sorular üzerinden genel başarı yüzdesi.
  int get averageSuccessPercentage =>
      totalQuestions == 0 ? 0 : ((totalCorrect / totalQuestions) * 100).round();

  int get bestSuccessPercentage => attempts.isEmpty
      ? 0
      : attempts
          .map((attempt) => attempt.successPercentage)
          .reduce((a, b) => a > b ? a : b);

  int get passedAttemptCount =>
      attempts.where((attempt) => attempt.passed).length;

  TestAttempt? get lastAttempt => attempts.isEmpty ? null : attempts.first;

  /// Bir testin en iyi denemesi; hiç çözülmediyse `null`.
  TestAttempt? bestAttemptFor(int testNumber) {
    final matching =
        attempts.where((attempt) => attempt.testNumber == testNumber).toList();
    if (matching.isEmpty) return null;

    matching.sort(
      (a, b) => b.successPercentage.compareTo(a.successPercentage),
    );
    return matching.first;
  }

  /// Konu bazlı başarı; yalnızca cevaplanmış kategoriler yer alır.
  Map<QuestionCategory, CategoryScore> get byCategory {
    final totals = <QuestionCategory, CategoryScore>{};

    for (final attempt in attempts) {
      for (final entry in attempt.categoryScores.entries) {
        final existing = totals[entry.key];
        totals[entry.key] =
            existing == null ? entry.value : existing + entry.value;
      }
    }

    return totals;
  }

  /// En zayıf konu; AI koçun çalışma önerisi buna dayanacak.
  QuestionCategory? get weakestCategory {
    final entries = byCategory.entries
        .where((entry) => entry.value.total >= 2)
        .toList()
      ..sort((a, b) => a.value.ratio.compareTo(b.value.ratio));

    return entries.isEmpty ? null : entries.first.key;
  }
}

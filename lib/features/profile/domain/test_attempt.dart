import '../../quiz/domain/question.dart';

/// Bir kategoride verilen doğru/toplam cevap sayısı.
class CategoryScore {
  const CategoryScore({required this.correct, required this.total});

  final int correct;
  final int total;

  int get wrong => total - correct;

  double get ratio => total == 0 ? 0 : correct / total;
  int get percentage => (ratio * 100).round();

  CategoryScore operator +(CategoryScore other) =>
      CategoryScore(correct: correct + other.correct, total: total + other.total);

  Map<String, dynamic> toJson() => {'correct': correct, 'total': total};

  static CategoryScore fromJson(Map<String, dynamic> json) => CategoryScore(
        correct: json['correct'] as int? ?? 0,
        total: json['total'] as int? ?? 0,
      );
}

/// Tamamlanmış bir test denemesinin kaydı.
class TestAttempt {
  const TestAttempt({
    required this.testNumber,
    required this.correctCount,
    required this.questionCount,
    required this.completedAt,
    required this.categoryScores,
  });

  /// Geçme notu sayılan başarı yüzdesi.
  static const int passingPercentage = 70;

  final int testNumber;
  final int correctCount;
  final int questionCount;
  final DateTime completedAt;
  final Map<QuestionCategory, CategoryScore> categoryScores;

  int get wrongCount => questionCount - correctCount;

  int get successPercentage =>
      questionCount == 0 ? 0 : ((correctCount / questionCount) * 100).round();

  bool get passed => successPercentage >= passingPercentage;

  Map<String, dynamic> toJson() => {
        'testNumber': testNumber,
        'correctCount': correctCount,
        'questionCount': questionCount,
        'completedAt': completedAt.toIso8601String(),
        'categoryScores': {
          for (final entry in categoryScores.entries)
            entry.key.name: entry.value.toJson(),
        },
      };

  static TestAttempt fromJson(Map<String, dynamic> json) {
    final rawScores = json['categoryScores'];
    final scores = <QuestionCategory, CategoryScore>{};

    if (rawScores is Map<String, dynamic>) {
      for (final entry in rawScores.entries) {
        final category = QuestionCategory.values
            .where((value) => value.name == entry.key)
            .firstOrNull;
        final value = entry.value;
        if (category != null && value is Map<String, dynamic>) {
          scores[category] = CategoryScore.fromJson(value);
        }
      }
    }

    return TestAttempt(
      testNumber: json['testNumber'] as int? ?? 0,
      correctCount: json['correctCount'] as int? ?? 0,
      questionCount: json['questionCount'] as int? ?? 0,
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? '') ??
          DateTime.now(),
      categoryScores: scores,
    );
  }
}

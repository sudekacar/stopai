import '../../quiz/domain/question.dart';

/// Ana menüdeki tek bir deneme testi.
class TestBundle {
  const TestBundle({
    required this.number,
    required this.title,
    required this.questions,
    required this.isFree,
  });

  /// 1'den başlayan test sırası.
  final int number;

  final String title;
  final List<Question> questions;

  /// Yalnızca 1. test ücretsizdir; diğerleri satın alma gerektirir.
  final bool isFree;

  String get id => 'test-${number.toString().padLeft(2, '0')}';

  int get questionCount => questions.length;

  /// Kartın altında gösterilen konu dağılımı, ör. "Trafik 4 · İlk Yardım 3".
  String get categorySummary {
    final counts = <QuestionCategory, int>{};
    for (final question in questions) {
      counts[question.category] = (counts[question.category] ?? 0) + 1;
    }

    final parts = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return parts.map((entry) => '${entry.key.label} ${entry.value}').join(' · ');
  }
}

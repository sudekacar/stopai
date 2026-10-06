/// Ehliyet sınavı soru kategorileri.
enum QuestionCategory {
  trafik('Trafik ve Çevre'),
  ilkYardim('İlk Yardım'),
  motor('Motor ve Araç Tekniği'),
  trafikAdabi('Trafik Adabı');

  const QuestionCategory(this.label);

  final String label;
}

/// Tek bir çoktan seçmeli soru.
class Question {
  const Question({
    required this.id,
    required this.category,
    required this.text,
    required this.options,
    required this.correctIndex,
    this.explanation,
  });

  final String id;
  final QuestionCategory category;
  final String text;
  final List<String> options;

  /// Doğru şıkkın [options] içindeki sırası.
  final int correctIndex;

  /// Cevaptan sonra gösterilen açıklama. İleride AI tarafından üretilecek.
  final String? explanation;

  String get correctOption => options[correctIndex];

  bool isCorrect(int index) => index == correctIndex;

  /// Soru bankası doğrulaması: en az iki şık ve geçerli bir doğru cevap.
  ///
  /// `const` yapıcıda `assert` kullanılamadığı için tutarlılık burada
  /// kontrol edilir; soru bankası testi bu alanı doğrular.
  bool get isValid =>
      options.length >= 2 && correctIndex >= 0 && correctIndex < options.length;
}

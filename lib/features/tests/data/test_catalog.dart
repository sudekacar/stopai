import 'dart:math';

import '../../quiz/data/question_bank.dart';
import '../../quiz/domain/question.dart';
import '../domain/test_bundle.dart';

/// 20 deneme testini soru bankasından üretir.
///
/// Dağıtım deterministiktir: test numarası tohum (seed) olarak kullanıldığı
/// için aynı test her açılışta aynı soruları aynı sırayla getirir. Kullanıcının
/// yarıda bıraktığı bir teste dönmesi ya da istatistiklerin tutarlı kalması
/// için bu gerekli.
abstract final class TestCatalog {
  static const int testCount = 20;
  static const int questionsPerTest = 10;

  /// İlk test ücretsiz; 2-20 arası satın alma ile açılır.
  static const int freeTestNumber = 1;

  static final List<TestBundle> all = List.unmodifiable(
    List.generate(testCount, (index) => _buildTest(index + 1)),
  );

  static TestBundle byNumber(int number) {
    assert(number >= 1 && number <= testCount, 'Geçersiz test numarası');
    return all[number - 1];
  }

  static TestBundle _buildTest(int number) {
    return TestBundle(
      number: number,
      title: 'Deneme Testi $number',
      questions: _pickQuestions(number),
      isFree: number == freeTestNumber,
    );
  }

  /// Bankayı test numarasına özel bir tohumla karıştırıp baştan pencere alır.
  ///
  /// Banka 40 soru, test başına 10 soru: testler arasında bir miktar tekrar
  /// kaçınılmaz, ama hem karıştırma hem kaydırma sayesinde her testin soru
  /// kümesi ve sırası farklı oluyor.
  static List<Question> _pickQuestions(int number) {
    final pool = [...QuestionBank.all]..shuffle(Random(number * 7919));
    final offset = ((number - 1) * questionsPerTest) % pool.length;

    return List.unmodifiable([
      for (var i = 0; i < questionsPerTest; i++) pool[(offset + i) % pool.length],
    ]);
  }
}

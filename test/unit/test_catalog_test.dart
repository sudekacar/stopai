import 'package:flutter_test/flutter_test.dart';
import 'package:stop_ai_ehliyet_kocu/features/quiz/data/question_bank.dart';
import 'package:stop_ai_ehliyet_kocu/features/tests/data/test_catalog.dart';

void main() {
  group('QuestionBank', () {
    test('her sorunun geçerli bir doğru cevabı var', () {
      for (final question in QuestionBank.all) {
        expect(question.isValid, isTrue, reason: question.id);
      }
    });

    test('soru kimlikleri tekil', () {
      final ids = QuestionBank.all.map((question) => question.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('her sorunun açıklaması var', () {
      for (final question in QuestionBank.all) {
        expect(question.explanation, isNotNull, reason: question.id);
        expect(question.explanation, isNotEmpty, reason: question.id);
      }
    });
  });

  group('TestCatalog', () {
    test('20 test üretilir', () {
      expect(TestCatalog.all, hasLength(20));
      expect(TestCatalog.testCount, 20);
    });

    test('yalnızca 1. test ücretsiz', () {
      expect(TestCatalog.byNumber(1).isFree, isTrue);

      for (var number = 2; number <= TestCatalog.testCount; number++) {
        expect(TestCatalog.byNumber(number).isFree, isFalse,
            reason: '$number. test ücretsiz olmamalı');
      }
    });

    test('her test eşit sayıda soru içerir', () {
      for (final bundle in TestCatalog.all) {
        expect(bundle.questionCount, TestCatalog.questionsPerTest);
      }
    });

    test('bir test içinde aynı soru iki kez yer almaz', () {
      for (final bundle in TestCatalog.all) {
        final ids = bundle.questions.map((question) => question.id).toList();
        expect(ids.toSet(), hasLength(ids.length), reason: bundle.id);
      }
    });

    test('test kimlikleri ve başlıkları tutarlı', () {
      expect(TestCatalog.byNumber(1).id, 'test-01');
      expect(TestCatalog.byNumber(20).id, 'test-20');
      expect(TestCatalog.byNumber(7).title, 'Deneme Testi 7');
    });

    test('soru dağıtımı deterministik: aynı test hep aynı soruları verir', () {
      final first = TestCatalog.byNumber(5).questions.map((q) => q.id).toList();
      final second = TestCatalog.byNumber(5).questions.map((q) => q.id).toList();

      expect(first, second);
    });

    test('farklı testler farklı soru kümeleri getirir', () {
      final first = TestCatalog.byNumber(1).questions.map((q) => q.id).toSet();
      final second = TestCatalog.byNumber(2).questions.map((q) => q.id).toSet();

      expect(first, isNot(second));
    });

    test('kategori özeti testteki kategorileri sayılarıyla listeler', () {
      final bundle = TestCatalog.byNumber(1);
      final categories = bundle.questions.map((q) => q.category).toSet();

      for (final category in categories) {
        final count =
            bundle.questions.where((q) => q.category == category).length;
        expect(bundle.categorySummary, contains('${category.label} $count'));
      }
    });
  });
}

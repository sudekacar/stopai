import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stop_ai_ehliyet_kocu/features/tests/data/test_catalog.dart';

import '../helpers/fake_backend.dart';
import '../helpers/pump_app.dart';

void main() {
  final freeTest = TestCatalog.byNumber(1);

  /// Ücretsiz testi baştan sona doğru cevaplarla çözer.
  Future<void> completeFreeTest(WidgetTester tester) async {
    await tapText(tester, 'Deneme Testi 1');

    for (var i = 0; i < TestCatalog.questionsPerTest; i++) {
      await tapText(tester, freeTest.questions[i].correctOption);

      final isLast = i == TestCatalog.questionsPerTest - 1;
      await tapButton(tester, isLast ? 'Testi Bitir' : 'Sonraki Soru');

      // 5. ve 10. soruda geçiş reklamı yer tutucusu araya girer.
      if (find.text('Interstitial yer tutucusu').evaluate().isNotEmpty) {
        await tapButton(tester, 'Devam et');
      }
    }
  }

  testWidgets('1. test kilitsiz açılır ve banner alanı görünür', (tester) async {
    await pumpSignedInApp(tester);

    await tapText(tester, 'Deneme Testi 1');

    expect(find.text('Soru 1'), findsOneWidget);
    expect(find.text(' / ${TestCatalog.questionsPerTest}'), findsOneWidget);
    expect(find.text('REKLAM'), findsOneWidget);
  });

  testWidgets('doğru cevapta yeşil "Doğru!" bildirimi çıkar', (tester) async {
    await pumpSignedInApp(tester);
    await tapText(tester, 'Deneme Testi 1');

    await tapText(tester, freeTest.questions.first.correctOption);

    expect(find.text('Doğru!'), findsOneWidget);
    expect(find.text('Yanlış!'), findsNothing);
  });

  testWidgets('yanlış cevapta lacivert "Yanlış!" bildirimi çıkar',
      (tester) async {
    await pumpSignedInApp(tester);
    await tapText(tester, 'Deneme Testi 1');

    final question = freeTest.questions.first;
    final wrongOption = question.options.firstWhere(
      (option) => option != question.correctOption,
    );
    await tapText(tester, wrongOption);

    expect(find.text('Yanlış!'), findsOneWidget);
    expect(find.text('Doğru!'), findsNothing);
    expect(find.text(question.explanation!), findsOneWidget);
  });

  testWidgets('5. soru geçilince geçiş reklamı yer tutucusu açılır',
      (tester) async {
    final harness = await pumpSignedInApp(tester);
    await tapText(tester, 'Deneme Testi 1');

    for (var i = 0; i < 5; i++) {
      await tapText(tester, freeTest.questions[i].correctOption);
      expect(
        find.text('Interstitial yer tutucusu'),
        findsNothing,
        reason: '${i + 1}. soru cevaplanırken reklam açılmamalı',
      );
      await tapButton(tester, 'Sonraki Soru');
    }

    expect(find.text('Interstitial yer tutucusu'), findsOneWidget);
    expect(harness.services.ads.interstitialTriggerCount, 1);

    await tapButton(tester, 'Devam et');
    expect(find.text('Soru 6'), findsOneWidget);
  });

  testWidgets('test bitince skor /results ucuna POST edilir', (tester) async {
    final harness = await pumpSignedInApp(tester);

    await completeFreeTest(tester);

    expect(find.text('%100'), findsOneWidget);
    expect(find.text('Tebrikler, geçtin!'), findsOneWidget);

    // Sunucuya tek bir sonuç yazıldı.
    expect(harness.backend.resultCount, 1);
    final saved = harness.backend.results.single;
    expect(saved.testId, 1);
    expect(saved.score, 100);

    // Ve profil sunucudan güncel özeti okudu.
    expect(harness.services.stats.completedTestCount, 1);
    expect(harness.services.stats.bestScore, 100);
  });

  testWidgets('sunucu kapalıyken skor kuyruğa alınır, bağlantıda gönderilir',
      (tester) async {
    final harness = await pumpSignedInApp(tester);
    harness.backend.offline = true;

    await completeFreeTest(tester);

    // Skor kaybolmadı: cihazda duruyor ve kuyrukta bekliyor.
    expect(find.text('%100'), findsOneWidget);
    expect(harness.services.stats.pendingCount, 1);
    expect(harness.backend.resultCount, 0);

    harness.backend.offline = false;
    await runService(tester, () => harness.services.stats.loadFor(testEmail));

    expect(harness.services.stats.pendingCount, 0);
    expect(harness.backend.resultCount, 1);
  });

  testWidgets('cevap verilmeden "Sonraki Soru" butonu pasif', (tester) async {
    await pumpSignedInApp(tester);
    await tapText(tester, 'Deneme Testi 1');

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Sonraki Soru'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('yarıda çıkışta onay sorulur', (tester) async {
    await pumpSignedInApp(tester);
    await tapText(tester, 'Deneme Testi 1');

    await tapText(tester, freeTest.questions.first.correctOption);
    await tapAppBarClose(tester);

    expect(find.text('Testten çıkılsın mı?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Çık'));
    await tester.pumpAndSettle();

    expect(find.text('Deneme Testleri'), findsOneWidget);
  });

  testWidgets('test kartı sunucudan gelen en iyi skoru gösterir',
      (tester) async {
    final backend = FakeBackend();
    await pumpSignedInApp(tester, backend: backend);

    await completeFreeTest(tester);
    await tapText(tester, 'Test Listesine Dön');

    expect(find.text('EN İYİ %100'), findsOneWidget);
  });
}

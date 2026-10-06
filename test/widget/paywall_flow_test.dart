import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('2-20 arası testler kilitli görünür', (tester) async {
    await pumpSignedInApp(tester);

    expect(find.text('ÜCRETSİZ'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);
    expect(find.text('19 test kilitli'), findsOneWidget);
  });

  testWidgets('kilitli teste dokununca paywall açılır ve metinler görünür',
      (tester) async {
    await pumpSignedInApp(tester);

    await tapText(tester, 'Deneme Testi 2');

    expect(find.text('🚨 FIRSAT!!'), findsOneWidget);
    expect(
      find.text(
        'Testlerin geri kalanını ömür boyu görmek için sadece 99 TL öde!',
      ),
      findsWidgets,
    );
    expect(
      find.text('AI ile görselli ve sesli çalışmak için sadece 299 TL!'),
      findsWidgets,
    );
    expect(find.text('99 TL - Satın Al'), findsOneWidget);
    expect(find.text('299 TL - Satın Al'), findsOneWidget);
  });

  testWidgets('99 TL satın alımı sunucuya yazılır, kilitler ve reklam kalkar',
      (tester) async {
    final harness = await pumpSignedInApp(tester);
    expect(harness.services.ads.adsEnabled, isTrue);

    await tapText(tester, 'Deneme Testi 2');
    await tapButton(tester, '99 TL - Satın Al');

    expect(find.text('Satın alma tamamlandı'), findsOneWidget);
    expect(find.text('Ömür Boyu Test Paketi Aktif'), findsOneWidget);

    // Paket durumu sunucuda güncellendi.
    expect(harness.backend.subscriptionOf(testEmail), 'lifetime_tests');
    expect(harness.services.entitlement.allTestsUnlocked, isTrue);
    expect(harness.services.ads.adsEnabled, isFalse);

    // "Devam Et" beklettiğimiz testi doğrudan açar.
    await tapButton(tester, 'Devam Et');
    expect(find.text('Deneme Testi 2'), findsOneWidget);
    expect(find.text('Soru 1'), findsOneWidget);
    expect(find.text('REKLAM'), findsNothing);
  });

  testWidgets('satın alma sonrası listede kilit kalmaz', (tester) async {
    await pumpSignedInApp(tester);

    await tapText(tester, 'Deneme Testi 2');
    await tapButton(tester, '99 TL - Satın Al');
    await tapButton(tester, 'Devam Et');
    await tapAppBarClose(tester);

    expect(find.text('19 test kilitli'), findsNothing);
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
  });

  testWidgets('99 TL paketi AI sekmesini açmaz', (tester) async {
    final harness = await pumpSignedInApp(tester);

    await tapText(tester, 'Deneme Testi 2');
    await tapButton(tester, '99 TL - Satın Al');
    await tapButton(tester, 'Devam Et');
    await tapAppBarClose(tester);

    await tapText(tester, 'AI Koç');

    expect(harness.services.entitlement.aiUnlocked, isFalse);
    expect(find.text('AI ile görselli çalışma'), findsOneWidget);
    expect(find.text('299 TL ile Kilidi Aç'), findsOneWidget);
  });

  testWidgets('299 TL satın alımı AI Pro paketini etkinleştirir',
      (tester) async {
    final harness = await pumpSignedInApp(tester);

    await tapText(tester, 'Deneme Testi 2');
    await tapButton(tester, '299 TL - Satın Al');

    expect(find.text('AI Pro Paket Aktif'), findsOneWidget);
    expect(harness.backend.subscriptionOf(testEmail), 'ai_pro');
    expect(harness.services.entitlement.aiUnlocked, isTrue);
  });

  testWidgets('sunucu kapalıysa satın alma yerelde açılır', (tester) async {
    final harness = await pumpSignedInApp(tester);
    harness.backend.offline = true;

    await tapText(tester, 'Deneme Testi 2');
    await tapButton(tester, '99 TL - Satın Al');

    expect(find.text('Satın alma tamamlandı'), findsOneWidget);
    expect(harness.services.entitlement.allTestsUnlocked, isTrue);
    expect(
      find.textContaining('Paket açıldı'),
      findsWidgets,
    );
  });

  testWidgets('kilitli test kartına dokunmak testi başlatmaz', (tester) async {
    await pumpSignedInApp(tester);

    await tapText(tester, 'Deneme Testi 5');

    expect(find.text('Soru 1'), findsNothing);
    expect(find.text('🚨 FIRSAT!!'), findsOneWidget);
  });

  testWidgets('paket sunucuda kayıtlıysa açılışta kilitler açık gelir',
      (tester) async {
    final harness = await pumpSignedInApp(
      tester,
      subscriptionStatus: 'ai_pro',
    );

    expect(find.text('19 test kilitli'), findsNothing);
    expect(harness.services.entitlement.aiUnlocked, isTrue);
    expect(harness.services.ads.adsEnabled, isFalse);
  });
}

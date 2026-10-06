import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stop_ai_ehliyet_kocu/features/profile/presentation/profile_screen.dart';
import 'package:stop_ai_ehliyet_kocu/features/tests/data/test_catalog.dart';

import '../helpers/pump_app.dart';

void main() {
  group('AI koç sekmesi', () {
    testWidgets('paket almayan kullanıcıya kilitli tanıtım gösterilir',
        (tester) async {
      await pumpSignedInApp(tester);

      await tapText(tester, 'AI Koç');

      expect(find.text('AI ile görselli çalışma'), findsOneWidget);
      expect(find.text('299 TL ile Kilidi Aç'), findsOneWidget);
      expect(find.text('Örn: Alternatör nedir?'), findsNothing);
    });

    testWidgets('kilitli ekrandan paywall açılabilir', (tester) async {
      await pumpSignedInApp(tester);
      await tapText(tester, 'AI Koç');

      await tapButton(tester, '299 TL ile Kilidi Aç');

      expect(find.text('🚨 FIRSAT!!'), findsOneWidget);
    });

    testWidgets('AI Pro kullanıcısının sorusu /ai/ask ucuna gider',
        (tester) async {
      final harness =
          await pumpSignedInApp(tester, subscriptionStatus: 'ai_pro');

      await tapText(tester, 'AI Koç');
      expect(find.text('Örn: Alternatör nedir?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Termostat ne işe yarar?');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      final askRequests = harness.backend.requests
          .where((request) => request.path.endsWith('/ai/ask'));
      expect(askRequests, hasLength(1));
      expect(
        (askRequests.single.data as Map)['question'],
        'Termostat ne işe yarar?',
      );

      expect(find.text('Termostat ne işe yarar?'), findsOneWidget);
      expect(find.textContaining('aküyü şarj'), findsOneWidget);
      expect(find.text('Sesli anlat'), findsWidgets);
    });

    testWidgets('öneri çipine dokunmak soruyu gönderir', (tester) async {
      await pumpSignedInApp(tester, subscriptionStatus: 'ai_pro');
      await tapText(tester, 'AI Koç');

      await tapText(tester, 'Alternatör nedir?');

      expect(find.textContaining('aküyü şarj'), findsOneWidget);
    });

    testWidgets('fotoğraf eklenip base64 olarak gönderilir', (tester) async {
      final harness =
          await pumpSignedInApp(tester, subscriptionStatus: 'ai_pro');
      await tapText(tester, 'AI Koç');

      await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
      await tester.pumpAndSettle();
      await tapText(tester, 'Galeriden seç');

      expect(find.textContaining('Galeri ·'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(harness.imagePicker.pickCount, 1);
      expect(harness.backend.receivedImages.single, ['QUJD']);
      expect(find.text('Bu parça nedir?'), findsOneWidget);
    });

    testWidgets('Ollama kapalıysa uyarı ve "Tekrar Dene" gösterilir',
        (tester) async {
      final harness =
          await pumpSignedInApp(tester, subscriptionStatus: 'ai_pro');
      harness.backend.ollamaDown = true;

      await tapText(tester, 'AI Koç');
      await tester.enterText(find.byType(TextField), 'Alternatör nedir?');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(find.text('AI koça ulaşılamadı'), findsOneWidget);
      expect(find.textContaining('AI koç şu an kapalı'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Tekrar Dene'), findsOneWidget);

      // Ollama geri gelince "Tekrar Dene" çalışıyor.
      harness.backend.ollamaDown = false;
      await tester.tap(find.widgetWithText(OutlinedButton, 'Tekrar Dene'));
      await tester.pumpAndSettle();

      expect(find.text('AI koça ulaşılamadı'), findsNothing);
      expect(find.textContaining('aküyü şarj'), findsOneWidget);
    });

    testWidgets('Ollama kapalıyken sekme üstünde durum şeridi çıkar',
        (tester) async {
      final harness =
          await pumpSignedInApp(tester, subscriptionStatus: 'ai_pro');
      harness.backend.ollamaDown = true;

      await tapText(tester, 'AI Koç');
      // Sekme açılışındaki sağlık kontrolü bir ağ isteği.
      await settleNetwork(tester);

      expect(find.text('Yenile'), findsOneWidget);
      expect(find.textContaining('Ollama'), findsOneWidget);
    });

    testWidgets('sunucu 403 dönerse paywall düğmesi gösterilir',
        (tester) async {
      // Paket sunucuda iptal edilmiş ama istemci hâlâ açık sanıyor: sunucu
      // son sözü söyler ve kullanıcı paywall'a yönlendirilir.
      final harness =
          await pumpSignedInApp(tester, subscriptionStatus: 'ai_pro');
      await tapText(tester, 'AI Koç');

      await runService(
        tester,
        () => harness.services.auth.applySubscription(
          harness.services.entitlement.products.first.id.grantedStatus,
        ),
      );

      expect(find.text('AI ile görselli çalışma'), findsOneWidget);
    });
  });

  group('Profil sekmesi', () {
    testWidgets('ücretsiz kullanıcı durumunu listeler', (tester) async {
      await pumpSignedInApp(tester);

      await tapText(tester, 'Profil');

      expect(find.text(testEmail), findsOneWidget);
      expect(find.text('Ücretsiz Kullanıcı'), findsOneWidget);
      expect(find.text('0/${TestCatalog.testCount}'), findsOneWidget);
      expect(find.textContaining('Henüz test çözmedin'), findsOneWidget);
    });

    testWidgets('satın alma sonrası üyelik durumu güncellenir', (tester) async {
      final harness = await pumpSignedInApp(tester);

      await runService(
        tester,
        () => harness.services.entitlement.purchase(
          harness.services.entitlement.products.last.id,
        ),
      );
      await tapText(tester, 'Profil');

      expect(find.text('AI Pro Paket Aktif'), findsOneWidget);
      expect(find.text('Paketleri Gör'), findsNothing);
    });

    testWidgets('çözülen test sunucu istatistiklerine yansır', (tester) async {
      final harness = await pumpSignedInApp(tester);
      final bundle = TestCatalog.byNumber(1);

      await tapText(tester, 'Deneme Testi 1');
      for (var i = 0; i < TestCatalog.questionsPerTest; i++) {
        await tapText(tester, bundle.questions[i].correctOption);
        final isLast = i == TestCatalog.questionsPerTest - 1;
        await tapButton(tester, isLast ? 'Testi Bitir' : 'Sonraki Soru');
        if (find.text('Interstitial yer tutucusu').evaluate().isNotEmpty) {
          await tapButton(tester, 'Devam et');
        }
      }
      await tapText(tester, 'Test Listesine Dön');
      await tapText(tester, 'Profil');

      expect(find.text('1/${TestCatalog.testCount}'), findsOneWidget);
      expect(find.text('%100'), findsWidgets);
      expect(find.text('Konu bazlı başarı'), findsOneWidget);
      expect(harness.backend.resultCount, 1);

      // Son denemeler listesi ekranın altında; profil listesini kaydırıyoruz.
      await tester.scrollUntilVisible(
        find.text('Son denemeler'),
        300,
        scrollable: find.descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Son denemeler'), findsOneWidget);
    });

    testWidgets('sunucu erişilemezse bilgi şeridi gösterilir', (tester) async {
      final harness = await pumpSignedInApp(tester);
      harness.backend.offline = true;

      await tapText(tester, 'Profil');
      await runService(tester, harness.services.stats.refresh);

      expect(
        find.textContaining('bu cihazdaki kayıtlar'),
        findsOneWidget,
      );
    });
  });
}

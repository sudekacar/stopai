import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stop_ai_ehliyet_kocu/core/storage/key_value_store.dart';
import 'package:stop_ai_ehliyet_kocu/core/storage/token_store.dart';

import '../helpers/fake_backend.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('açılışta giriş ekranı gösterilir', (tester) async {
    await pumpApp(tester);

    expect(find.text('Tekrar hoş geldin'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Giriş Yap'), findsOneWidget);
    // Oturum açılmadan reklam göstermiyoruz.
    expect(find.text('REKLAM'), findsNothing);
  });

  testWidgets('kayıt akışı backend\'e istek atıp ana menüye götürür',
      (tester) async {
    final harness = await pumpApp(tester);

    await tapText(tester, 'Üye Ol');
    expect(find.text('Hesap oluştur'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Adın ve soyadın'),
      testName,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ornek@eposta.com'),
      testEmail,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'En az 6 karakter, harf ve rakam'),
      testPassword,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Şifreni tekrar gir'),
      testPassword,
    );

    await tapButton(tester, 'Üye Ol');

    // Gerçek bir POST atıldı mı?
    final registerRequests = harness.backend.requests
        .where((request) => request.path.endsWith('/auth/register'));
    expect(registerRequests, hasLength(1));
    expect(registerRequests.single.method, 'POST');

    expect(find.text('Deneme Testleri'), findsOneWidget);
    expect(find.text('Merhaba Ali'), findsOneWidget);
    expect(find.text('Deneme Testi 1'), findsOneWidget);
  });

  testWidgets('giriş akışı /auth/login ucuna POST eder', (tester) async {
    final backend = FakeBackend()
      ..seedUser(email: testEmail, password: testPassword);
    await pumpApp(tester, backend: backend);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'ornek@eposta.com'),
      testEmail,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Şifreni gir'),
      testPassword,
    );
    await tapButton(tester, 'Giriş Yap');

    expect(
      backend.requests.where((r) => r.path.endsWith('/auth/login')),
      hasLength(1),
    );
    expect(find.text('Deneme Testleri'), findsOneWidget);
  });

  testWidgets('sunucudan gelen 401 mesajı ekranda gösterilir', (tester) async {
    final backend = FakeBackend()
      ..seedUser(email: testEmail, password: testPassword);
    await pumpApp(tester, backend: backend);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'ornek@eposta.com'),
      testEmail,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Şifreni gir'),
      'Yanlis999',
    );
    await tapButton(tester, 'Giriş Yap');

    expect(find.text('E-posta veya şifre hatalı.'), findsOneWidget);
    expect(find.text('Deneme Testleri'), findsNothing);
  });

  testWidgets('sunucu kapalıysa ağ hatası mesajı gösterilir', (tester) async {
    final backend = FakeBackend()..offline = true;
    await pumpApp(tester, backend: backend);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'ornek@eposta.com'),
      testEmail,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Şifreni gir'),
      testPassword,
    );
    await tapButton(tester, 'Giriş Yap');

    expect(find.textContaining('Sunucuya ulaşılamıyor'), findsOneWidget);
  });

  testWidgets('geçersiz form alanları istek atmadan hata gösterir',
      (tester) async {
    final harness = await pumpApp(tester);
    await tapText(tester, 'Üye Ol');

    await tester.enterText(
      find.widgetWithText(TextFormField, 'ornek@eposta.com'),
      'gecersiz-eposta',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'En az 6 karakter, harf ve rakam'),
      'kisa',
    );
    await tapButton(tester, 'Üye Ol');

    expect(find.text('Ad soyad gerekli.'), findsOneWidget);
    expect(find.text('Geçerli bir e-posta girin.'), findsOneWidget);
    expect(find.text('Şifre en az 6 karakter olmalı.'), findsOneWidget);
    // İstemci doğrulaması geçilmediği için sunucuya gidilmedi.
    expect(harness.backend.requests, isEmpty);
    expect(find.text('Hesap oluştur'), findsOneWidget);
  });

  testWidgets('saklanan anahtarla uygulama doğrudan ana menüde açılır',
      (tester) async {
    final backend = FakeBackend()
      ..seedUser(email: testEmail, password: testPassword);
    final store = InMemoryKeyValueStore();
    final tokenStore = InMemoryTokenStore();

    // Önce giriş yapıp anahtarı sakla.
    final first = await pumpApp(
      tester,
      backend: backend,
      store: store,
      tokenStore: tokenStore,
    );
    await runService(
      tester,
      () => first.services.auth.login(
        email: testEmail,
        password: testPassword,
      ),
    );

    // Uygulama yeniden açılıyor: aynı anahtar ve depo.
    await pumpApp(
      tester,
      backend: backend,
      store: store,
      tokenStore: tokenStore,
    );

    expect(find.text('Deneme Testleri'), findsOneWidget);
    expect(find.text('Tekrar hoş geldin'), findsNothing);
    // Açılışta anahtar sunucuya doğrulatıldı.
    expect(
      backend.requests.where((r) => r.path.endsWith('/auth/me')),
      isNotEmpty,
    );
  });

  testWidgets('sunucu anahtarı reddederse giriş ekranına dönülür',
      (tester) async {
    final backend = FakeBackend();
    final tokenStore = InMemoryTokenStore('artik-gecersiz');

    await pumpApp(tester, backend: backend, tokenStore: tokenStore);

    expect(find.text('Tekrar hoş geldin'), findsOneWidget);
    expect(await tokenStore.read(), isNull);
  });

  testWidgets('profilden çıkış yapınca giriş ekranına dönülür', (tester) async {
    await pumpSignedInApp(tester);

    await tapText(tester, 'Profil');
    await tapText(tester, 'Çıkış Yap');

    // Onay diyalogundaki buton, arkadaki butonla aynı metni taşıyor.
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Çıkış Yap'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tekrar hoş geldin'), findsOneWidget);
  });
}

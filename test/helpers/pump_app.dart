import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stop_ai_ehliyet_kocu/app.dart';
import 'package:stop_ai_ehliyet_kocu/core/app_scope.dart';
import 'package:stop_ai_ehliyet_kocu/core/network/api_service.dart';
import 'package:stop_ai_ehliyet_kocu/core/services/purchase_service.dart';
import 'package:stop_ai_ehliyet_kocu/core/storage/key_value_store.dart';
import 'package:stop_ai_ehliyet_kocu/core/storage/token_store.dart';
import 'package:stop_ai_ehliyet_kocu/features/ai/data/image_picker_service.dart';
import 'package:stop_ai_ehliyet_kocu/features/ai/domain/ai_message.dart';

import 'fake_backend.dart';

/// Testlerde kullanılan sabit hesap.
const String testEmail = 'surucu@stopkoc.com';
const String testPassword = 'Sifre123';
const String testName = 'Ali Veli';

/// Kamera/galeri yerine sabit bir görsel döndüren seçici.
class FakeImagePicker implements ImagePickerService {
  FakeImagePicker({AiAttachment? attachment})
      : attachment = attachment ?? defaultAttachment;

  /// "ABC" metninin base64'ü; gerçek bayt içeriği testte önemli değil.
  static const AiAttachment defaultAttachment = AiAttachment(
    fileName: 'motor_bolumu.jpg',
    source: 'Galeri',
    base64Data: 'QUJD',
  );

  /// `null` yapıldığında kullanıcı vazgeçmiş gibi davranır.
  AiAttachment? attachment;

  int pickCount = 0;
  bool? lastFromCamera;

  @override
  Future<AiAttachment?> pick({required bool fromCamera}) async {
    pickCount++;
    lastFromCamera = fromCamera;
    return attachment;
  }
}

/// Test için hazırlanmış servis kümesi ve onun sahte sunucusu.
class TestHarness {
  TestHarness({
    required this.services,
    required this.backend,
    required this.store,
    required this.imagePicker,
  });

  final AppServices services;
  final FakeBackend backend;
  final KeyValueStore store;
  final FakeImagePicker imagePicker;
}

/// Sahte sunucuya bağlı bir `ApiService` üretir.
ApiService createTestApiService(
  FakeBackend backend, {
  TokenStore? tokenStore,
}) {
  final dio = Dio()..httpClientAdapter = backend;

  final api = ApiService(
    tokenStore: tokenStore ?? InMemoryTokenStore(),
    baseUrl: 'http://test${FakeBackend.basePath}',
    dio: dio,
  );

  // Zaman aşımlarını kapatıyoruz. `testWidgets` sahte bir saat kullandığı
  // için Dio'nun kurduğu zamanlayıcılar ilerlemiyor ve `pumpAndSettle`
  // sonsuza kadar bekliyor. Sahte sunucu anında yanıt verdiğinden zaman
  // aşımına da gerek yok.
  api.dio.options
    ..connectTimeout = null
    ..receiveTimeout = null
    ..sendTimeout = null;

  return api;
}

/// Uygulamayı telefon boyutunda bir yüzeyde, sahte sunucuya bağlı başlatır.
///
/// Varsayılan 800x600 masaüstü yüzeyi kullanılmıyor: alt butonlar görünür
/// alanın dışında kalıyor ve test ortamında gerçek font olmadığı için
/// metinler gerçek cihazdan geniş ölçülüyor.
Future<TestHarness> pumpApp(
  WidgetTester tester, {
  FakeBackend? backend,
  KeyValueStore? store,
  TokenStore? tokenStore,
  PurchaseService? purchaseService,
}) async {
  tester.view.physicalSize = const Size(440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final fakeBackend = backend ?? FakeBackend();
  final keyValueStore = store ?? InMemoryKeyValueStore();
  final imagePicker = FakeImagePicker();

  final services = AppServices(
    store: keyValueStore,
    api: createTestApiService(fakeBackend, tokenStore: tokenStore),
    imagePicker: imagePicker,
    purchaseService: purchaseService,
  );
  addTearDown(services.dispose);

  // Açılışta kayıtlı anahtar sunucuya doğrulatılıyor; bu ağ çağrısının
  // gerçek zamanlı bölgede çalışması gerekiyor.
  await tester.runAsync(services.bootstrap);
  await tester.pumpWidget(StopApp(services: services));
  await tester.pumpAndSettle();

  return TestHarness(
    services: services,
    backend: fakeBackend,
    store: keyValueStore,
    imagePicker: imagePicker,
  );
}

/// Arayüzü gezmeden oturum açar: giriş akışını test etmeyen senaryolar için.
Future<TestHarness> pumpSignedInApp(
  WidgetTester tester, {
  FakeBackend? backend,
  KeyValueStore? store,
  String subscriptionStatus = 'free',
  PurchaseService? purchaseService,
}) async {
  final harness = await pumpApp(
    tester,
    backend: backend,
    store: store,
    purchaseService: purchaseService,
  );

  harness.backend.seedUser(
    email: testEmail,
    password: testPassword,
    subscriptionStatus: subscriptionStatus,
  );

  await runService(tester, () async {
    await harness.services.auth.login(
      email: testEmail,
      password: testPassword,
    );
    // Giriş dinleyicisi istatistik yüklemesini ateşler; bitmesini
    // bekleyelim ki sonraki adımlar (ör. çevrimdışı yenileme) yarışmasın.
    await harness.services.waitForPendingWork();
  });

  await settleNetwork(tester);

  return harness;
}

/// Arka planda süren ağ isteklerinin tamamlanmasını bekler.
///
/// Widget kodundan başlayan istekler (ör. sekme açılışındaki sağlık kontrolü,
/// oturum açılınca tetiklenen istatistik yüklemesi) sahte saat altında
/// çalışıyor ve `pumpAndSettle` tek başına onları ilerletmiyor.
/// [WidgetTester.runAsync] gerçek zamanlı bir pencere açıyor, ardından gelen
/// `pumpAndSettle` sonucu ekrana yansıtıyor.
Future<void> settleNetwork(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }
}

/// Servis çağrılarını arayüzü kullanmadan yürütür.
///
/// Bu çağrıların içinde gecikmeli `Future`'lar var (ör. mağaza satın alma
/// simülasyonu). `testWidgets` sahte bir saat kullandığı için doğrudan
/// `await` edilirse zaman hiç ilerlemez ve test kilitlenir;
/// [WidgetTester.runAsync] gerçek zamanlı bir bölge açarak bunu çözer.
Future<T?> runService<T>(
  WidgetTester tester,
  Future<T> Function() action,
) async {
  final result = await tester.runAsync(action);
  await tester.pumpAndSettle();
  return result;
}

/// Öğeyi görünür alana kaydırıp dokunur.
Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Bir butona etiketiyle dokunur (aynı metin başka yerde de geçebileceği için).
Future<void> tapButton(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(ElevatedButton, label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// AppBar'daki kapatma düğmesine dokunur.
///
/// `Icons.close_rounded` ekranda başka yerlerde de geçiyor (ör. yanlış cevap
/// sayacı), bu yüzden arama AppBar ile sınırlanıyor.
Future<void> tapAppBarClose(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(Icons.close_rounded),
    ),
  );
  await tester.pumpAndSettle();
}

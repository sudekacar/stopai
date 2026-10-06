import 'package:flutter_test/flutter_test.dart';
import 'package:stop_ai_ehliyet_kocu/core/network/network_status.dart';
import 'package:stop_ai_ehliyet_kocu/core/observability/crash_reporter.dart';
import 'package:stop_ai_ehliyet_kocu/core/services/purchase_service.dart';

import '../helpers/fake_purchase_service.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('çevrimdışı banner kayıtlı içerikle birlikte görünür',
      (tester) async {
    final harness = await pumpSignedInApp(tester);

    harness.services.network.setOffline(true);
    await tester.pump();

    expect(find.text('Çevrimdışı Mod'), findsOneWidget);
    expect(
      find.text('Kayıtlı testlerin ve profilin kullanılabilir.'),
      findsOneWidget,
    );
    expect(find.text('Deneme Testi 1'), findsOneWidget);
  });

  testWidgets('sandbox satın alma hatası dialog açar', (tester) async {
    final purchases = FakePurchaseService()
      ..purchaseError = const PurchaseException(
        'Sandbox makbuzu doğrulanamadı.',
        kind: PurchaseFailureKind.sandbox,
      );

    await pumpSignedInApp(tester, purchaseService: purchases);

    await tapText(tester, 'Deneme Testi 2');
    await tapButton(tester, '99 TL - Satın Al');

    expect(find.text('Test / Sandbox hatası'), findsOneWidget);
    expect(find.text('Sandbox makbuzu doğrulanamadı.'), findsWidgets);
  });

  test('NetworkStatus setOffline dinleyicileri uyarır', () {
    final network = NetworkStatus();
    var ticks = 0;
    network.addListener(() => ticks++);

    network.setOffline(true);
    expect(network.isOffline, isTrue);
    expect(ticks, 1);

    network.setOffline(true);
    expect(ticks, 1);

    network.setOffline(false);
    expect(network.isOnline, isTrue);
    expect(ticks, 2);

    network.dispose();
  });

  test('CrashReporter no-op init hata fırlatmaz', () async {
    const reporter = CrashReporter();
    await reporter.init();
    await reporter.log('ping');
    await reporter.recordError(StateError('x'), StackTrace.empty);
    await reporter.setUserId('1');
  });
}

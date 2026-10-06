import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_scope.dart';
import 'core/network/api_service.dart';
import 'core/network/network_status.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/observability/firebase_crash_reporter.dart';
import 'core/services/purchase_service.dart';
import 'core/storage/hive_key_value_store.dart';
import 'core/storage/key_value_store.dart';
import 'core/storage/token_store.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final crashReporter = FirebaseCrashReporter();
    await crashReporter.init();

    FlutterError.onError = (details) {
      crashReporter.recordFlutterError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(crashReporter.recordError(error, stack, fatal: true));
      return true;
    };

    final store = await _openStore();
    final api = ApiService(tokenStore: SecureTokenStore());
    final purchases = PurchaseService.revenueCat();
    final services = AppServices(
      store: store,
      api: api,
      purchaseService: purchases,
      crashReporter: crashReporter,
      network: NetworkStatus.platform(),
      pushNotifications: FirebasePushNotificationService(
        store: store,
        crashReporter: crashReporter,
      ),
    );

    await services.bootstrap();
    runApp(StopApp(services: services));
  }, (error, stack) {
    debugPrint('[main] yakalanmamış hata: $error');
  });
}

Future<KeyValueStore> _openStore() async {
  try {
    return await HiveKeyValueStore.open();
  } on Object catch (error) {
    debugPrint('[main] Hive açılamadı, SharedPreferences: $error');
    return SharedPreferencesStore.open();
  }
}

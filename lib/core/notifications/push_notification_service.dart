import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../observability/crash_reporter.dart';
import '../storage/key_value_store.dart';

/// FCM arka plan mesajları isolate'ta çalışır; üst düzey fonksiyon olmalı.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseBootstrap.ensureInitialized();
}

/// Push bildirim sözleşmesi. Testler no-op örneğe bağlanır.
class PushNotificationService {
  const PushNotificationService();

  String? get token => null;

  bool get isReady => false;

  Future<void> init() async {}

  Future<void> syncUser(String? userId) async {}
}

/// Firebase Cloud Messaging: izin, token ve konu abonelikleri.
///
/// Günlük test hatırlatması ve motivasyon mesajları Firebase Console /
/// Cloud Functions üzerinden `daily_test_reminders` ve `motivation_messages`
/// konularına gönderilir.
class FirebasePushNotificationService extends PushNotificationService {
  FirebasePushNotificationService({
    required this.store,
    this.crashReporter = const CrashReporter(),
  });

  static const String tokenKey = 'fcm.token';
  static const String dailyRemindersTopic = 'daily_test_reminders';
  static const String motivationTopic = 'motivation_messages';

  final KeyValueStore store;
  final CrashReporter crashReporter;

  String? _token;
  bool _ready = false;

  @override
  String? get token => _token ?? store.getString(tokenKey);

  @override
  bool get isReady => _ready;

  @override
  Future<void> init() async {
    final firebaseReady = await FirebaseBootstrap.ensureInitialized();
    if (!firebaseReady) return;

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        await crashReporter.log('FCM izni reddedildi');
        return;
      }

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      await _persistToken(await messaging.getToken());
      messaging.onTokenRefresh.listen(_persistToken);

      await messaging.subscribeToTopic(dailyRemindersTopic);
      await messaging.subscribeToTopic(motivationTopic);

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      _ready = true;
    } on Object catch (error, stack) {
      await crashReporter.recordError(error, stack);
    }
  }

  @override
  Future<void> syncUser(String? userId) async {
    if (userId == null || userId.isEmpty) return;
    await crashReporter.log('FCM kullanıcı eşlemesi: $userId');
  }

  Future<void> _persistToken(String? value) async {
    if (value == null || value.isEmpty) return;
    _token = value;
    await store.setString(tokenKey, value);
    if (kDebugMode) {
      debugPrint('[FCM] token güncellendi (${value.length} karakter)');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'];
    if (kDebugMode) {
      debugPrint('[FCM] ön plan mesajı: $title');
    }
  }
}

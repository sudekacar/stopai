import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase yapılandırması `--dart-define` ile gelir.
///
/// Üretimde `flutterfire configure` çıktısını buraya koyabilir veya
/// derlemede şu anahtarları geçebilirsiniz:
/// `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`,
/// `FIREBASE_PROJECT_ID`, `FIREBASE_STORAGE_BUCKET`.
///
/// Değerler boşsa Crashlytics ve FCM başlatılmaz; uygulama çalışmaya devam eder.
abstract final class DefaultFirebaseOptions {
  static const String apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );
  static const String appId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '',
  );
  static const String messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '',
  );
  static const String projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: '',
  );
  static const String storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: '',
  );

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  static FirebaseOptions get current {
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
    );
  }

  static FirebaseOptions get currentPlatform => current;
}

/// Firebase'i bir kez, yapılandırma varsa başlatır.
abstract final class FirebaseBootstrap {
  static bool _ready = false;
  static bool _attempted = false;

  static bool get isReady => _ready;

  static Future<bool> ensureInitialized() async {
    if (_ready) return true;
    if (_attempted) return false;
    _attempted = true;

    if (!DefaultFirebaseOptions.isConfigured) {
      if (kDebugMode) {
        debugPrint(
          '[Firebase] Yapılandırma yok. Crashlytics/FCM atlandı. '
          '--dart-define=FIREBASE_API_KEY=... ile verin.',
        );
      }
      return false;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.current);
      }
      _ready = true;
      return true;
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('[Firebase] başlatılamadı: $error');
      }
      return false;
    }
  }
}

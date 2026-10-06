import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import 'crash_reporter.dart';

/// Firebase Crashlytics sarmalayıcısı.
///
/// Firebase yapılandırması yoksa [CrashReporter] gibi sessizce no-op olur;
/// uygulama yine de açılır.
class FirebaseCrashReporter extends CrashReporter {
  FirebaseCrashlytics? _crashlytics;

  @override
  Future<void> init() async {
    final ready = await FirebaseBootstrap.ensureInitialized();
    if (!ready) return;

    try {
      final crashlytics = FirebaseCrashlytics.instance;
      await crashlytics.setCrashlyticsCollectionEnabled(true);
      _crashlytics = crashlytics;

      FlutterError.onError = (details) {
        crashlytics.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        crashlytics.recordError(error, stack, fatal: true);
        return true;
      };
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('[CrashReporter] Crashlytics bağlanamadı: $error');
      }
    }
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  }) async {
    await super.recordError(error, stack, fatal: fatal);
    try {
      await _crashlytics?.recordError(error, stack, fatal: fatal);
    } on Object {
      // Raporlama kendi hatası uygulamayı düşürmesin.
    }
  }

  @override
  Future<void> log(String message) async {
    await super.log(message);
    try {
      await _crashlytics?.log(message);
    } on Object {
      // yoksay
    }
  }

  @override
  Future<void> setUserId(String? userId) async {
    try {
      await _crashlytics?.setUserIdentifier(userId ?? '');
    } on Object {
      // yoksay
    }
  }
}

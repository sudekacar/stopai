import 'package:flutter/foundation.dart';

/// Çökme ve beklenmeyen hata raporlama sözleşmesi.
///
/// Üretimde [FirebaseCrashReporter] kullanılır; testler varsayılan no-op
/// örneğine bağlanır. Native SDK buradan çağrılmaz.
class CrashReporter {
  const CrashReporter();

  Future<void> init() async {}

  Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  }) async {
    if (kDebugMode) {
      debugPrint('[CrashReporter] ${fatal ? 'FATAL' : 'error'}: $error');
    }
  }

  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    FlutterError.presentError(details);
    await recordError(
      details.exception,
      details.stack ?? StackTrace.empty,
      fatal: true,
    );
  }

  Future<void> log(String message) async {
    if (kDebugMode) debugPrint('[CrashReporter] $message');
  }

  Future<void> setUserId(String? userId) async {}
}
